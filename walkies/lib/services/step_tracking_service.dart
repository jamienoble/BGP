import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/supabase_service.dart';

class StepTrackingService {
  static final StepTrackingService _instance =
      StepTrackingService._internal();

  factory StepTrackingService() {
    return _instance;
  }

  StepTrackingService._internal();

  late Stream<StepCount> _stepCountStream;
  int _lastRecordedSteps = 0;

  final SupabaseService _supabaseService = SupabaseService();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastRecordedSteps = prefs.getInt('last_recorded_steps') ?? 0;

    _stepCountStream = Pedometer.stepCountStream;

    _stepCountStream.listen((StepCount event) {
      _updateSteps(event.steps);
    });
  }

  Future<void> _updateSteps(int currentSteps) async {
    try {
      await _supabaseService.upsertTodaySteps(currentSteps);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_recorded_steps', currentSteps);
      _lastRecordedSteps = currentSteps;
    } catch (e) {
      // Silently handle errors to avoid console spam
    }
  }

  Stream<StepCount> get stepCountStream => _stepCountStream;

  int get lastRecordedSteps => _lastRecordedSteps;

  Future<void> resetDailySteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_recorded_steps', 0);
    _lastRecordedSteps = 0;
  }
}
