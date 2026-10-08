import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/services/notification_service.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/goal_rules.dart';
import 'package:walkies/screens/goal_management_screen.dart';
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

  int? _savedGoal; // Goal as saved; may only apply from tomorrow
  int _dailyGoal = AppConstants.defaultDailyStepGoal; // Goal in force today
  int _currentSteps = 0;
  bool? _lastGoalMet;
  bool _isLoading = true;
  StreamSubscription<int>? _stepSubscription;

  // Streak tracking
  Map<DateTime, bool> _dailyGoalsMet = {};
  int _currentStreak = 0;

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
    } else if (state == AppLifecycleState.paused) {
      _stepTrackingService.flushToCloud();
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
    final prefs = await SharedPreferences.getInstance();
    final today = date_utils.DateUtils.todayDateString();

    // Goal completed: notify once per day
    if (currentSteps >= goalSteps) {
      if (prefs.getString(AppConstants.prefGoalCompletedNotifiedDate) != today) {
        await prefs.setString(AppConstants.prefGoalCompletedNotifiedDate, today);
        await prefs.setString(AppConstants.prefGoalNearNotifiedDate, today);
        await _notificationService.sendGoalCompletedNotification();
      }
      return;
    }

    // Reached ~80% of goal: notify once per day
    if (progress >= AppConstants.notificationThresholdPercent &&
        prefs.getString(AppConstants.prefGoalNearNotifiedDate) != today) {
      await prefs.setString(AppConstants.prefGoalNearNotifiedDate, today);
      await _notificationService.sendGoalNearCompletionNotification(
        currentSteps: currentSteps,
        goalSteps: goalSteps,
        stepsRemaining: goalSteps - currentSteps,
      );
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

  /// Load which recent days had goals met and work out the current streak.
  /// Days the app saw are taken from the local record (judged against the
  /// goal at the time); any others are filled from cloud history in one
  /// request. Days up to a streak reset never count.
  Future<void> _loadDailyGoalsMet() async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;
      final prefs = await SharedPreferences.getInstance();
      final streakMap = await _readStreakMap(prefs);
      final resetDate = DateTime.tryParse(
        prefs.getString(AppConstants.prefStreakResetDate) ?? '',
      );

      final today = date_utils.DateUtils.getDayStart(DateTime.now());
      const historyDays = AppConstants.dayHistoryLimit;
      final days = List.generate(
        historyDays,
        (i) => DateTime(today.year, today.month, today.day - i),
      );

      final missing = days.where((d) => !streakMap.containsKey(_dateKey(d)));
      if (missing.isNotEmpty) {
        final history = await _supabaseService.getStepsHistory(historyDays);
        final stepsByDay = {
          for (final entry in history) _dateKey(entry.date): entry.steps,
        };
        for (final day in missing) {
          final key = _dateKey(day);
          if (DateUtils.isSameDay(day, today)) continue;
          streakMap[key] = (stepsByDay[key] ?? 0) >= _dailyGoal;
        }
      }

      bool metOn(DateTime day) {
        if (resetDate != null && !day.isAfter(resetDate)) return false;
        return streakMap[_dateKey(day)] ?? false;
      }

      // Count back from today; today may still be in progress
      int streak = 0;
      for (int i = 0; i < days.length; i++) {
        if (metOn(days[i])) {
          streak++;
        } else if (i != 0) {
          break;
        }
      }

      final goalsMet = {for (final day in days.take(7)) day: metOn(day)};

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
      // Initialize step tracking (requests permission internally if needed)
      await _stepTrackingService.initialize();

      final goal = await _supabaseService.getStepGoal();
      final dailyGoal = await GoalRules.effectiveGoal(goal?.dailySteps);
      // Seed from DB in case the pedometer hasn't fired yet
      final today = await _supabaseService.getTodaySteps();

      if (mounted) {
        setState(() {
          _savedGoal = goal?.dailySteps;
          _dailyGoal = dailyGoal;
          // Take whichever is further along: the local count or the last cloud sync
          _currentSteps = max(_stepTrackingService.todaySteps, today?.steps ?? 0);
          _isLoading = false;
        });
        // Persist goal and steps to prefs for accessibility service
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.prefDailyGoal, dailyGoal);
        await prefs.setInt(AppConstants.prefTodaySteps, _currentSteps);
        await _appLockerService.syncNativeStepGoalPrefs(
          dailyGoal: dailyGoal,
          todaySteps: _currentSteps,
        );
        await _updateTodayStreakStatus(_currentSteps, dailyGoal);
        _lastGoalMet = _currentSteps >= dailyGoal;
        await _loadDailyGoalsMet();
      }

      // Rebuild the native locked-app list from the cloud on every load
      await _appLockerService.syncLockedAppsToAccessibilityService();

      // Listen to live step updates (today's delta, not raw lifetime count).
      // _loadData runs on every resume, so drop the previous listener first.
      await _stepSubscription?.cancel();
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
          final dailyGoal = _dailyGoal;
          await _appLockerService.syncNativeStepGoalPrefs(
            dailyGoal: dailyGoal,
            todaySteps: steps,
          );
          await _updateTodayStreakStatus(steps, dailyGoal);
          // Only recompute the streak when today's status flips
          final goalMet = steps >= dailyGoal;
          if (goalMet != _lastGoalMet) {
            _lastGoalMet = goalMet;
            await _loadDailyGoalsMet();
          }

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

  /// Sign out. The auth wrapper in main.dart switches to the login screen.
  Future<void> _signOut() async {
    try {
      await _stepTrackingService.flushToCloud();
      // Locks belong to the account; don't leave them enforced signed out
      await _appLockerService.clearAccessibilityServiceLockedApps();
      await _supabaseService.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, step history, goal and '
          'app locks. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabaseService.deleteAccount();
      await _appLockerService.clearAccessibilityServiceLockedApps();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final goalSteps = _dailyGoal;
    final progress = goalSteps > 0 ? _currentSteps / goalSteps : 0.0;
    final goalMet = _currentSteps >= goalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walkies Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signOut') _signOut();
              if (value == 'delete') _deleteAccount();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'signOut', child: Text('Sign out')),
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
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
                              'of $goalSteps steps',
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
                subtitle: Text(
                  _savedGoal != null && _savedGoal != goalSteps
                      ? '$goalSteps steps today, $_savedGoal from tomorrow'
                      : '$goalSteps steps',
                ),
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
