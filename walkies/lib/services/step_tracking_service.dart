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
  int _todaySteps = 0; // Today's step count (delta from baseline)

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
        // Same day — restore saved baseline
        _pedometerBaseline =
            prefs.getInt(AppConstants.prefStepBaselineValue) ?? 0;
        _baselineDate = savedDate;
      } else {
        // New day — mark that we need to capture baseline on first step event
        _baselineDate = ''; // Signal that baseline needs to be set
        _pedometerBaseline = 0;
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

    // Apply sensor filtering to detect and reject noisy spikes
    if (!_shouldProcessStepEvent(rawSteps, now)) {
      return;
    }

    // Calculate and broadcast today's step count
    _updateTodaySteps(rawSteps);

    // Persist locally and to cloud
    await prefs.setInt(AppConstants.prefTodaySteps, _todaySteps);
    await _syncToSupabase();
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
    prefs.setInt(AppConstants.prefStepBaselineValue, _pedometerBaseline);
    prefs.setString(AppConstants.prefStepBaselineDate, _baselineDate);
    _lastRawSteps = rawSteps;
    _lastStepEventAt = now;
    _todayStepsController.add(0);
    prefs.setInt(AppConstants.prefTodaySteps, 0);
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
    _todaySteps =
        (rawSteps - _pedometerBaseline).clamp(0, AppConstants.maxStepsValue);
    _todayStepsController.add(_todaySteps);
  }

  /// Sync today's step count to Supabase
  Future<void> _syncToSupabase() async {
    try {
      await _supabaseService.upsertTodaySteps(_todaySteps);
    } catch (_) {
      // Silently ignore sync errors (e.g., offline)
    }
  }

  /// Stream of today's step count (delta from start of day)
  Stream<int> get todayStepsStream => _todayStepsController.stream;

  int get todaySteps => _todaySteps;

  bool get isInitialized => _isInitialized;

  String? get initializationError => _initializationError;
}
