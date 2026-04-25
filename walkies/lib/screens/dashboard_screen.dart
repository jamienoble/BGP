import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/services/notification_service.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/widgets/weekly_streak_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabaseService = SupabaseService();
  final _stepTrackingService = StepTrackingService();
  final _notificationService = NotificationService();

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
    _loadData();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }

  /// Initialize notification service and load daily streak data
  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      await _loadDailyGoalsMet();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Load which days of the week had goals met
  Future<void> _loadDailyGoalsMet() async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;

      // Get last 7 days of daily steps
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));

      Map<DateTime, bool> goalsMet = {};

      for (int i = 0; i < 7; i++) {
        final date = sevenDaysAgo.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        // Get daily steps for this date
        final dailySteps = await _supabaseService.getTodayStepsForDate(dateStr);
        final stepGoal = _stepGoal?.dailySteps ?? 7000;

        goalsMet[DateTime(date.year, date.month, date.day)] =
            (dailySteps?.steps ?? 0) >= stepGoal;
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

      if (mounted) {
        setState(() {
          _dailyGoalsMet = goalsMet;
          _currentStreak = streak;
        });
      }
    } catch (e) {
      print('Error loading daily goals: $e');
    }
  }

  Future<void> _loadData() async {
    try {
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
        await prefs.setInt('daily_goal', goal?.dailySteps ?? 7000);
        await prefs.setInt('today_steps', _currentSteps);
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
          await prefs.setInt('today_steps', steps);

          // Handle notifications
          final goalSteps = _stepGoal?.dailySteps ?? 7000;
          final progress = (steps / goalSteps) * 100;

          // Send notification when reaching ~80% of goal
          if (progress >= 80 && !_goalNotificationSent && goalSteps > 0) {
            _goalNotificationSent = true;
            await _notificationService.sendGoalNearCompletionNotification(
              currentSteps: steps,
              goalSteps: goalSteps,
              stepsRemaining: (goalSteps - steps).clamp(0, goalSteps),
            );
          }

          // Send notification when goal is completed
          if (steps >= goalSteps && goalSteps > 0) {
            await _notificationService.sendGoalCompletedNotification();
            await _loadDailyGoalsMet(); // Update streak
          }
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

  Future<void> _signOut() async {
    try {
      await _supabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
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
                  color: Colors.red[100],
                  border: Border.all(color: Colors.red[700]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step Tracking Issue',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepTrackingService.initializationError!,
                      style: TextStyle(color: Colors.red[800], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
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

            // Goal Management
            Card(
              elevation: 4,
              child: ListTile(
                title: const Text('Daily Goal'),
                subtitle: Text('${goalSteps} steps'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => const GoalManagementScreen(),
                        ),
                      )
                      .then((_) => _loadData());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
