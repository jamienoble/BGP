import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';

class StepTrackingService {
  static final StepTrackingService _instance =
      StepTrackingService._internal();

  factory StepTrackingService() {
    return _instance;
  }

  StepTrackingService._internal();

  // Stream controller so the dashboard can listen to today's step count
  final _todayStepsController = StreamController<int>.broadcast();

  bool _isInitialized = false;
  String? _initializationError;

  // Raw pedometer value at the start of today (used to calculate delta)
  int _pedometerBaseline = 0;
  // Today's date string (yyyy-MM-dd) when baseline was recorded
  String _baselineDate = '';
  // Current today's step count
  int _todaySteps = 0;
  int _lastRawSteps = 0;
  DateTime? _lastStepEventAt;

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
          _initializationError =
              'Activity recognition permission denied. Please grant it in Settings.';
          return;
        }
      }

      // Load saved baseline from prefs
      final prefs = await SharedPreferences.getInstance();
      final todayDate = _todayDateString();
      final savedDate = prefs.getString('step_baseline_date') ?? '';
      final appInstallBaseline = prefs.getInt('step_app_install_baseline') ?? 0;

      if (savedDate == todayDate) {
        // Same day — restore saved baseline
        _pedometerBaseline = prefs.getInt('step_baseline_value') ?? 0;
        _baselineDate = savedDate;
      } else {
        // New day — use the app install baseline (to count historical steps)
        _pedometerBaseline = appInstallBaseline;
        _baselineDate = todayDate;
      }

      // If app install baseline not yet set, it will be set on first pedometer event
      if (appInstallBaseline == 0) {
        print('Step tracking: App install baseline not yet set, will be set on first pedometer event');
      }

      Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          _initializationError = 'Failed to access step sensor: $error';
        },
      );

      _isInitialized = true;
    } catch (e) {
      _initializationError = 'Failed to initialize step tracking: $e';
    }
  }

  void _onStepCount(StepCount event) async {
    final rawSteps = event.steps;
    final todayDate = _todayDateString();
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();

    // On very first app launch, save the current pedometer value as the app install baseline
    // This allows us to count historical steps from before the app was installed
    final appInstallBaseline = prefs.getInt('step_app_install_baseline') ?? 0;
    if (appInstallBaseline == 0) {
      await prefs.setInt('step_app_install_baseline', rawSteps);
      print('Step tracking: Set app install baseline to $rawSteps');
    }

    // If it's a new day or baseline not yet set, record this as the baseline
    if (_baselineDate != todayDate || _pedometerBaseline == 0) {
      _pedometerBaseline = rawSteps;
      _baselineDate = todayDate;
      await prefs.setInt('step_baseline_value', _pedometerBaseline);
      await prefs.setString('step_baseline_date', _baselineDate);
      _lastRawSteps = rawSteps;
      _lastStepEventAt = now;
      _todayStepsController.add(0);
      await prefs.setInt("today_steps", 0);
      return;
    }

    // Basic sanity filtering to avoid noisy spikes from over-sensitive sensors.
    if (_lastRawSteps > 0 && rawSteps < _lastRawSteps) {
      return;
    }
    if (_lastRawSteps > 0 && _lastStepEventAt != null) {
      final deltaSteps = rawSteps - _lastRawSteps;
      final elapsedSeconds =
          now.difference(_lastStepEventAt!).inMilliseconds / 1000.0;
      if (elapsedSeconds > 0) {
        final stepsPerSecond = deltaSteps / elapsedSeconds;
        // Ignore implausible bursts (e.g. shake/noise events).
        if (stepsPerSecond > 4.0) {
          return;
        }
      }
    }

    _lastRawSteps = rawSteps;
    _lastStepEventAt = now;

    // Today's steps = current raw value minus the baseline at start of day
    _todaySteps = (rawSteps - _pedometerBaseline).clamp(0, 999999);

    // Broadcast to listeners
    _todayStepsController.add(_todaySteps);

    // Persist to local prefs (for accessibility service to read)\n    await prefs.setInt("today_steps", _todaySteps);\n\n    // Persist to Supabase
    try {
      await _supabaseService.upsertTodaySteps(_todaySteps);
    } catch (_) {
      // Silently ignore sync errors
    }
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Stream of today's step count (delta from start of day)
  Stream<int> get todayStepsStream => _todayStepsController.stream;

  int get todaySteps => _todaySteps;

  bool get isInitialized => _isInitialized;

  String? get initializationError => _initializationError;
}
