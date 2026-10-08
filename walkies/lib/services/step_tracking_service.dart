import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

class StepTrackingService {
  static final StepTrackingService _instance =
      StepTrackingService._internal();

  factory StepTrackingService() {
    return _instance;
  }

  StepTrackingService._internal();

  // Stream controller broadcasts step count changes to UI listeners (e.g., dashboard)
  final _todayStepsController = StreamController<int>.broadcast();

  bool _isInitialized = false;
  String? _initializationError;

  // Baseline tracking for daily reset
  int _pedometerBaseline = 0; // Raw pedometer value at start of today
  String _baselineDate = ''; // Date when baseline was captured (yyyy-MM-dd)
  int _todaySteps = 0; // Today's step count
  int _carriedSteps = 0; // Steps counted today before the sensor last restarted (reboot)

  // Cloud sync throttling: steps are saved at most once per interval,
  // plus whenever the app goes to the background
  DateTime? _lastCloudSyncAt;
  int? _lastSyncedSteps;

  // Sensor data filtering
  int _lastRawSteps = 0; // Previous raw pedometer reading
  DateTime? _lastStepEventAt; // Timestamp of previous event

  final SupabaseService _supabaseService = SupabaseService();
  final PermissionsService _permissionsService = PermissionsService();

  Future<void> initialize() async {
    // Prevent multiple initialization attempts
    if (_isInitialized) return;

    try {
      // Check permission first (don't request — let the UI handle requesting
      // to avoid race conditions with other permission requests)
      final hasPermission =
          await _permissionsService.hasActivityRecognitionPermission();

      if (!hasPermission) {
        // Try requesting once here
        final granted =
            await _permissionsService.requestActivityRecognitionPermission();
        if (!granted) {
          _initializationError = AppConstants.errorActivityPermissionDenied;
          return;
        }
      }

      // Load saved baseline from prefs
      final prefs = await SharedPreferences.getInstance();
      final todayDate = date_utils.DateUtils.todayDateString();
      final savedDate = prefs.getString(AppConstants.prefStepBaselineDate) ?? '';

      if (savedDate == todayDate) {
        // Same day — restore saved baseline and progress
        _pedometerBaseline =
            prefs.getInt(AppConstants.prefStepBaselineValue) ?? 0;
        _carriedSteps = prefs.getInt(AppConstants.prefStepCarried) ?? 0;
        _lastRawSteps = prefs.getInt(AppConstants.prefStepLastRaw) ?? 0;
        _todaySteps = prefs.getInt(AppConstants.prefTodaySteps) ?? 0;
        _baselineDate = savedDate;
      } else {
        // New day — mark that we need to capture baseline on first step event
        _baselineDate = ''; // Signal that baseline needs to be set
        _pedometerBaseline = 0;
        _carriedSteps = 0;
        _todaySteps = 0;
      }

      Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          _initializationError =
              '${AppConstants.errorStepSensorFailed}: $error';
        },
      );

      _isInitialized = true;
    } catch (e) {
      _initializationError = '${AppConstants.errorInitializationFailed}: $e';
    }
  }

  void _onStepCount(StepCount event) async {
    final rawSteps = event.steps;
    final todayDate = date_utils.DateUtils.todayDateString();
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();

    // Record app install baseline on first app launch
    _recordAppInstallBaselineIfNeeded(prefs, rawSteps);

    // Reset baseline at start of new day
    if (_baselineDate != todayDate) {
      _resetDailyBaseline(prefs, rawSteps, todayDate, now);
      return;
    }

    // Step counter went backwards: the device restarted and the sensor's
    // since-boot count began again. Keep today's progress and rebase.
    if (rawSteps < _lastRawSteps || rawSteps < _pedometerBaseline) {
      _handleSensorRestart(prefs, rawSteps, now);
    }

    // Apply sensor filtering to detect and reject noisy spikes
    if (!_shouldProcessStepEvent(rawSteps, now)) {
      return;
    }

    // Calculate and broadcast today's step count
    _updateTodaySteps(rawSteps);

    // Persist locally and to cloud
    await prefs.setInt(AppConstants.prefTodaySteps, _todaySteps);
    await prefs.setInt(AppConstants.prefStepLastRaw, _lastRawSteps);
    final lastSync = _lastCloudSyncAt;
    if (lastSync == null ||
        now.difference(lastSync) >= AppConstants.cloudSyncInterval) {
      await _syncToSupabase();
    }
  }

  /// Record the pedometer value on very first app launch
  /// This baseline allows counting historical steps from before app installation
  void _recordAppInstallBaselineIfNeeded(SharedPreferences prefs, int rawSteps) {
    final appInstallBaseline =
        prefs.getInt(AppConstants.prefStepAppInstallBaseline) ?? 0;
    if (appInstallBaseline == 0) {
      prefs.setInt(AppConstants.prefStepAppInstallBaseline, rawSteps);
    }
  }

  /// Reset daily baseline when a new day is detected
  /// This captures today's starting pedometer value so we can calculate delta
  void _resetDailyBaseline(
    SharedPreferences prefs,
    int rawSteps,
    String todayDate,
    DateTime now,
  ) {
    _pedometerBaseline = rawSteps;
    _baselineDate = todayDate;
    _carriedSteps = 0;
    _todaySteps = 0;
    prefs.setInt(AppConstants.prefStepBaselineValue, _pedometerBaseline);
    prefs.setString(AppConstants.prefStepBaselineDate, _baselineDate);
    prefs.setInt(AppConstants.prefStepCarried, 0);
    prefs.setInt(AppConstants.prefStepLastRaw, rawSteps);
    _lastRawSteps = rawSteps;
    _lastStepEventAt = now;
    _todayStepsController.add(0);
    prefs.setInt(AppConstants.prefTodaySteps, 0);
  }

  /// Rebase after the sensor's count restarts, carrying today's steps over
  void _handleSensorRestart(
    SharedPreferences prefs,
    int rawSteps,
    DateTime now,
  ) {
    _carriedSteps = _todaySteps;
    _pedometerBaseline = rawSteps;
    _lastRawSteps = rawSteps;
    _lastStepEventAt = now;
    prefs.setInt(AppConstants.prefStepBaselineValue, _pedometerBaseline);
    prefs.setInt(AppConstants.prefStepCarried, _carriedSteps);
    prefs.setInt(AppConstants.prefStepLastRaw, rawSteps);
  }

  /// Check if step event should be processed or filtered out as noise
  bool _shouldProcessStepEvent(int rawSteps, DateTime now) {
    // Reject if step count goes backwards (device reset or sensor error)
    if (_lastRawSteps > 0 && rawSteps < _lastRawSteps) {
      return false;
    }

    // Reject implausible step bursts (likely sensor noise or device shaking)
    if (_lastRawSteps > 0 && _lastStepEventAt != null) {
      final deltaSteps = rawSteps - _lastRawSteps;
      final elapsedSeconds =
          now.difference(_lastStepEventAt!).inMilliseconds / 1000.0;
      if (elapsedSeconds > 0) {
        final stepsPerSecond = deltaSteps / elapsedSeconds;
        if (stepsPerSecond > AppConstants.maxStepsPerSecond) {
          return false;
        }
      }
    }

    return true;
  }

  /// Calculate today's step count as delta from baseline and broadcast
  void _updateTodaySteps(int rawSteps) {
    _lastRawSteps = rawSteps;
    _lastStepEventAt = DateTime.now();
    _todaySteps = (_carriedSteps + rawSteps - _pedometerBaseline)
        .clamp(0, AppConstants.maxStepsValue);
    _todayStepsController.add(_todaySteps);
  }

  /// Sync today's step count to Supabase
  Future<void> _syncToSupabase() async {
    _lastCloudSyncAt = DateTime.now();
    final steps = todaySteps;
    try {
      await _supabaseService.upsertTodaySteps(steps);
      _lastSyncedSteps = steps;
    } catch (_) {
      // Ignore sync errors (e.g., offline); retried on the next interval
    }
  }

  /// Save any unsynced steps now (call when the app goes to the background)
  Future<void> flushToCloud() async {
    if (!_isInitialized || _baselineDate.isEmpty) return;
    if (todaySteps == _lastSyncedSteps) return;
    await _syncToSupabase();
  }

  /// Stream of today's step count (delta from start of day)
  Stream<int> get todayStepsStream => _todayStepsController.stream;

  /// Today's steps; 0 if the stored count belongs to an earlier day and no
  /// step event has arrived yet today.
  int get todaySteps =>
      _baselineDate == date_utils.DateUtils.todayDateString() ? _todaySteps : 0;

  bool get isInitialized => _isInitialized;

  String? get initializationError => _initializationError;
}
