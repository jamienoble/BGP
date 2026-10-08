import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/services/notification_service.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/goal_rules.dart';
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

  int _dailyGoal = AppConstants.defaultDailyStepGoal; // Goal in force today
  String? _preferredName;
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
    
    // Check if a locked app was opened before reaching the goal
    // (recorded by the native blocker)
    final blockedAppOpenedBeforeGoal =
        await _appLockerService.wasLockedAppOpenedBeforeGoalToday();
    
    // Only count today as streak success if:
    // 1. Not reset today
    // 2. Goal is met
    // 3. No blocked apps were opened before goal was met
    streakMap[todayKey] = !wasResetToday && steps >= goalSteps && !blockedAppOpenedBeforeGoal;

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
      await _stepTrackingService.refreshForToday();

      final goal = await _supabaseService.getStepGoal();
      final dailyGoal = await GoalRules.effectiveGoal(goal?.dailySteps);
      await _supabaseService.ensureUserProfile();
      final preferredName = await _supabaseService.getPreferredName();
      // Seed from DB in case the pedometer hasn't fired yet
      final today = await _supabaseService.getTodaySteps();

      if (mounted) {
        setState(() {
          _dailyGoal = dailyGoal;
          _preferredName = preferredName;
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

      // Avoid duplicate listeners when screen resumes repeatedly.
      await _stepSubscription?.cancel();

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final goalSteps = _dailyGoal;
    final progress = goalSteps > 0 ? _currentSteps / goalSteps : 0.0;
    final goalMet = _currentSteps >= goalSteps;
    final stepsRemaining = (goalSteps - _currentSteps).clamp(0, goalSteps);
    final stepDigits = _currentSteps
        .clamp(0, 99999)
        .toString()
        .padLeft(5, '0')
        .split('');
    final distanceKm = (_currentSteps * 0.0008);
    final greetingName = _preferredName ?? _userDisplayName();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_greeting()}, $greetingName',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              goalMet
                  ? 'Goal complete - your apps are unlocked'
                  : '$stepsRemaining steps until you unlock',
              style: TextStyle(fontSize: 16, color: const Color(0xFF5D7B6D)),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: const Color(0xFFE8D7C3)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(stepDigits.length, (index) {
                      final digit = stepDigits[index];
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == stepDigits.length - 1 ? 0 : 8,
                          ),
                          child: Container(
                            height: 116,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5EFE5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE8D7C3)),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      ((int.parse(digit) + 9) % 10).toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF8BA39E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: const Color(0xFFE8D7C3),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Center(
                                    child: Text(
                                      digit,
                                      style: const TextStyle(
                                        fontSize: 40,
                                        height: 1.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D5A4A),
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: const Color(0xFFE8D7C3),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      ((int.parse(digit) + 1) % 10).toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF8BA39E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_currentSteps steps',
                        style: const TextStyle(
                          color: Color(0xFF2D5A4A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '/$goalSteps',
                        style: TextStyle(
                          color: const Color(0xFF8BA39E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.deepPurple,
                    backgroundColor: Colors.deepPurple.shade100,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statCard('DISTANCE', distanceKm.toStringAsFixed(1), 'km'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard('STREAK', '$_currentStreak', 'days'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S NUDGE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentSteps < goalSteps * 0.5
                        ? 'A 10-min walk now can make a big dent in your goal.'
                        : 'You are over halfway there. Keep your momentum going.',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WeeklyStreakWidget(
            dailyGoalsMet: _dailyGoalsMet,
            currentStreak: _currentStreak,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AppLockSettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('App Locks'),
                ),
              ),
            ],
          ),
          if (_stepTrackingService.initializationError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12.0),
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
          ],
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _userDisplayName() {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      return 'there';
    }
    final localPart = email.split('@').first;
    final cleaned = localPart.split(RegExp(r'[._-]')).first;
    if (cleaned.isEmpty) {
      return 'there';
    }
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  Widget _statCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
