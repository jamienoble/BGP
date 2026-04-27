import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/services/notification_service.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/widgets/weekly_streak_widget.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _supabaseService = SupabaseService();
  final _stepTrackingService = StepTrackingService();
  final _notificationService = NotificationService();
  final _appLockerService = AppLockerService();

  StepGoal? _stepGoal;
  int _currentSteps = 0;
  bool _isLoading = true;
  StreamSubscription<int>? _stepSubscription;

  // Streak tracking
  Map<DateTime, bool> _dailyGoalsMet = {};
  int _currentStreak = 0;
  bool _goalNotificationSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _initializeNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// Reset the notification flag if it's a new day
  Future<void> _resetNotificationFlagIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = date_utils.DateUtils.todayDateString();
    final lastResetDate = prefs.getString(AppConstants.prefLastNotificationResetDate);

    if (lastResetDate != today) {
      _goalNotificationSent = false;
      await prefs.setString(AppConstants.prefLastNotificationResetDate, today);
    }
  }

  /// Initialize notification service and load daily streak data
  Future<void> _initializeNotifications() async {
    try {
      await PermissionsService().requestNotificationPermission();
      await _notificationService.initialize();
      await _loadDailyGoalsMet();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Handle step update notifications based on progress towards goal
  Future<void> _handleStepUpdateNotifications(int currentSteps, int goalSteps) async {
    if (goalSteps <= 0) return;

    final progress = (currentSteps / goalSteps) * 100;

    // Send notification when reaching ~80% of goal
    if (progress >= AppConstants.notificationThresholdPercent && !_goalNotificationSent) {
      _goalNotificationSent = true;
      await _notificationService.sendGoalNearCompletionNotification(
        currentSteps: currentSteps,
        goalSteps: goalSteps,
        stepsRemaining: (goalSteps - currentSteps).clamp(0, goalSteps),
      );
    }

    // Send notification when goal is completed
    if (currentSteps >= goalSteps) {
      await _notificationService.sendGoalCompletedNotification();
    }
  }

  String _dateKey(DateTime date) => date_utils.DateUtils.todayDateString(dateTime: date);

  Future<Map<String, bool>> _readStreakMap(SharedPreferences prefs) async {
    final raw = prefs.getString(AppConstants.prefStreakDaysMet);
    if (raw == null || raw.isEmpty) return <String, bool>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> _writeStreakMap(
    SharedPreferences prefs,
    Map<String, bool> streakMap,
  ) async {
    await prefs.setString(AppConstants.prefStreakDaysMet, jsonEncode(streakMap));
  }

  Future<void> _updateTodayStreakStatus(int steps, int goalSteps) async {
    if (goalSteps <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final streakMap = await _readStreakMap(prefs);
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final resetDate = prefs.getString(AppConstants.prefStreakResetDate);
    final wasResetToday = resetDate == todayKey;

    streakMap[todayKey] = !wasResetToday && steps >= goalSteps;

    // Keep only recent entries
    final cutoff = today.subtract(Duration(days: AppConstants.dayHistoryLimit));
    streakMap.removeWhere((k, _) {
      final parsed = DateTime.tryParse(k);
      if (parsed == null) return true;
      return parsed.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
    });
    await _writeStreakMap(prefs, streakMap);
  }

  /// Load which days of the week had goals met
  Future<void> _loadDailyGoalsMet() async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;
      final prefs = await SharedPreferences.getInstance();
      final streakMap = await _readStreakMap(prefs);

      // Get last 7 days of daily steps
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));

      Map<DateTime, bool> goalsMet = {};

      for (int i = 0; i < 7; i++) {
        final date = sevenDaysAgo.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        final dayKey = _dateKey(date);
        if (streakMap.containsKey(dayKey)) {
          goalsMet[DateTime(date.year, date.month, date.day)] =
              streakMap[dayKey] ?? false;
          continue;
        }

        // Get daily steps for this date
        final dailySteps = await _supabaseService.getTodayStepsForDate(dateStr);
        final stepGoal = _stepGoal?.dailySteps ?? AppConstants.defaultDailyStepGoal;

        goalsMet[DateTime(date.year, date.month, date.day)] =
            (dailySteps?.steps ?? 0) >= stepGoal;
        streakMap[dayKey] = goalsMet[DateTime(date.year, date.month, date.day)]!;
      }

      // Calculate current streak
      int streak = 0;
      for (int i = 6; i >= 0; i--) {
        final date = sevenDaysAgo.add(Duration(days: i));
        if (goalsMet[DateTime(date.year, date.month, date.day)] ?? false) {
          streak++;
        } else if (i != 6) {
          // Only break if it's not today (allow today to be incomplete)
          break;
        }
      }
      await _writeStreakMap(prefs, streakMap);
      await prefs.setInt(AppConstants.prefStreakCurrent, streak);

      if (mounted) {
        setState(() {
          _dailyGoalsMet = goalsMet;
          _currentStreak = streak;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily goals: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      // Reset notification flag if it's a new day
      await _resetNotificationFlagIfNewDay();

      // Initialize step tracking (requests permission internally if needed)
      await _stepTrackingService.initialize();

      final goal = await _supabaseService.getStepGoal();
      // Seed from DB in case the pedometer hasn't fired yet
      final today = await _supabaseService.getTodaySteps();

      if (mounted) {
        setState(() {
          _stepGoal = goal;
          _currentSteps = _stepTrackingService.todaySteps > 0
              ? _stepTrackingService.todaySteps
              : (today?.steps ?? 0);
          _isLoading = false;
        });
        // Persist goal and steps to prefs for accessibility service
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.prefDailyGoal, goal?.dailySteps ?? AppConstants.defaultDailyStepGoal);
        await prefs.setInt(AppConstants.prefTodaySteps, _currentSteps);
        await _appLockerService.syncNativeStepGoalPrefs(
          dailyGoal: goal?.dailySteps ?? AppConstants.defaultDailyStepGoal,
          todaySteps: _currentSteps,
        );
        await _updateTodayStreakStatus(_currentSteps, goal?.dailySteps ?? AppConstants.defaultDailyStepGoal);
        await _loadDailyGoalsMet();
      }

      // Listen to live step updates (today's delta, not raw lifetime count)
      _stepSubscription = _stepTrackingService.todayStepsStream.listen((
        steps,
      ) async {
        if (mounted) {
          setState(() {
            _currentSteps = steps;
          });
          // Persist to prefs for accessibility service
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(AppConstants.prefTodaySteps, steps);
          final dailyGoal =
              _stepGoal?.dailySteps ?? AppConstants.defaultDailyStepGoal;
          await _appLockerService.syncNativeStepGoalPrefs(
            dailyGoal: dailyGoal,
            todaySteps: steps,
          );
          await _updateTodayStreakStatus(steps, dailyGoal);
          await _loadDailyGoalsMet();

          // Handle notifications
          await _handleStepUpdateNotifications(steps, dailyGoal);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final goalSteps = _stepGoal?.dailySteps ?? 0;
    final progress = goalSteps > 0 ? _currentSteps / goalSteps : 0.0;
    final goalMet = _currentSteps >= goalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walkies Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Permission warning if step tracking failed
            if (_stepTrackingService.initializationError != null)
              Container(
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Needed',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Walkies needs Activity Recognition permission to keep your step progress accurate.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                          ),
                          onPressed: () async {
                            final permissionsService = PermissionsService();
                            await permissionsService.openAppSettings();
                          },
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _loadData,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // Steps Progress Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Today\'s Steps',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 8,
                            color: goalMet ? Colors.green : Colors.orange,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_currentSteps',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'of ${goalSteps} steps',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (goalMet)
                      const Chip(
                        label: Text('Goal Met! 🎉'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      Chip(
                        label: Text('${goalSteps - _currentSteps} steps to go'),
                        backgroundColor: Colors.orange,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Weekly Streak Widget
            WeeklyStreakWidget(
              dailyGoalsMet: _dailyGoalsMet,
              currentStreak: _currentStreak,
            ),
            const SizedBox(height: 24),

            // App Lock Status
            Card(
              elevation: 4,
              child: ListTile(
                title: const Text('App Locks Active'),
                subtitle: const Text('Tap to manage locked apps'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppLockSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Goal Management - moved to settings
          ],
        ),
      ),
    );
  }
}
