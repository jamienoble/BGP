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
import 'package:walkies/services/error_reporter.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/models/daily_steps.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/widgets/weekly_streak_widget.dart';
import 'package:walkies/widgets/ui.dart';
import 'package:walkies/theme/app_theme.dart';
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
  bool _blockerOff = false;
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
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stack,
        context: 'Error initializing notifications',
      );
    }
  }

  /// Handle step update notifications based on progress towards goal
  Future<void> _handleStepUpdateNotifications(
    int currentSteps,
    int goalSteps,
  ) async {
    if (goalSteps <= 0) return;

    final progress = (currentSteps / goalSteps) * 100;
    final prefs = await SharedPreferences.getInstance();
    final today = date_utils.DateUtils.todayDateString();

    // Goal completed: notify once per day
    if (currentSteps >= goalSteps) {
      if (prefs.getString(AppConstants.prefGoalCompletedNotifiedDate) !=
          today) {
        await prefs.setString(
          AppConstants.prefGoalCompletedNotifiedDate,
          today,
        );
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

  String _dateKey(DateTime date) =>
      date_utils.DateUtils.todayDateString(dateTime: date);

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
    await prefs.setString(
      AppConstants.prefStreakDaysMet,
      jsonEncode(streakMap),
    );
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
    final blockedAppOpenedBeforeGoal = await _appLockerService
        .wasLockedAppOpenedBeforeGoalToday();

    // Only count today as streak success if:
    // 1. Not reset today
    // 2. Goal is met
    // 3. No blocked apps were opened before goal was met
    streakMap[todayKey] =
        !wasResetToday && steps >= goalSteps && !blockedAppOpenedBeforeGoal;

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
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'Error loading daily goals');
    }
  }

  /// Runs [request], returning [fallback] if it fails (e.g. offline), so
  /// one failed request doesn't blank the whole screen.
  Future<T> _orFallback<T>(Future<T> request, T fallback, String what) async {
    try {
      return await request;
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'Dashboard: $what');
      return fallback;
    }
  }

  Future<void> _loadData() async {
    try {
      // Initialize step tracking (requests permission internally if needed)
      await _stepTrackingService.initialize();
      await _stepTrackingService.refreshForToday();

      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait<Object?>([
        _orFallback(_supabaseService.getStepGoal(), null, 'goal'),
        _orFallback(
          _supabaseService.ensureUserProfile().then(
            (_) => _supabaseService.getPreferredName(),
          ),
          _preferredName,
          'name',
        ),
        // Seed from the cloud in case the pedometer hasn't fired yet
        _orFallback(_supabaseService.getTodaySteps(), null, 'cloud steps'),
        _appLockerService.getNativeTodaySteps(),
        _orFallback(_appLockerService.getLockedAppsList(), null, 'locked apps'),
        _appLockerService.isAppLockingEnabled(),
      ]);
      final goal = results[0] as StepGoal?;
      // Offline: fall back to the last goal this phone knew about
      final savedGoal =
          goal?.dailySteps ?? prefs.getInt(AppConstants.prefDailyGoal);
      final dailyGoal = await GoalRules.effectiveGoal(savedGoal);
      final cloudSteps = (results[2] as DailySteps?)?.steps ?? 0;
      final nativeSteps = results[3] as int? ?? 0;
      final lockedApps = results[4] as List<AppLock>?;
      final blockerEnabled = results[5] as bool;

      if (mounted) {
        setState(() {
          _dailyGoal = dailyGoal;
          _preferredName = results[1] as String?;
          // Show the same count the app blocker uses
          _currentSteps = [
            _stepTrackingService.todaySteps,
            cloudSteps,
            nativeSteps,
          ].reduce(max);
          // Locks set but Android has switched the blocker off: they won't
          // be enforced, so say so. (Null list = couldn't check; stay quiet.)
          _blockerOff = !blockerEnabled && (lockedApps?.isNotEmpty ?? false);
          _isLoading = false;
        });
        // Persist goal and steps to prefs for accessibility service
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
        appSteps,
      ) async {
        if (!mounted) return;
        final dailyGoal = _dailyGoal;
        // Pass the app's count to the blocker, then show the blocker's view
        // (which also includes steps the phone's sensor counted)
        await _appLockerService.syncNativeStepGoalPrefs(
          dailyGoal: dailyGoal,
          todaySteps: appSteps,
        );
        final nativeSteps = await _appLockerService.getNativeTodaySteps() ?? 0;
        final steps = max(appSteps, nativeSteps);
        if (!mounted) return;
        setState(() {
          _currentSteps = steps;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.prefTodaySteps, steps);
        await _updateTodayStreakStatus(steps, dailyGoal);
        // Only recompute the streak when today's status flips
        final goalMet = steps >= dailyGoal;
        if (goalMet != _lastGoalMet) {
          _lastGoalMet = goalMet;
          await _loadDailyGoalsMet();
        }

        // Handle notifications
        await _handleStepUpdateNotifications(steps, dailyGoal);
      });
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'Dashboard: load');
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

    final text = Theme.of(context).textTheme;
    final goalSteps = _dailyGoal;
    final progress = goalSteps > 0
        ? (_currentSteps / goalSteps).clamp(0.0, 1.0)
        : 0.0;
    final goalMet = _currentSteps >= goalSteps;
    final distanceKm = _currentSteps * 0.0008;
    final activeMinutes = (_currentSteps / 100).round();
    final greetingName = _preferredName ?? _userDisplayName();
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: AppSpacing.page,
        children: [
          Text(
            '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}'
                .toUpperCase(),
            style: text.labelSmall,
          ),
          const SizedBox(height: 6),
          Text('${_greeting()}, $greetingName', style: text.headlineLarge),
          const SizedBox(height: 18),
          if (_stepTrackingService.initializationError != null) ...[
            NoticeCard(
              tone: NoticeTone.warning,
              icon: Icons.directions_walk_rounded,
              title: 'Step counting is off',
              message:
                  'Allow physical activity access so Walkies can count '
                  'your steps and unlock your apps.',
              actions: [
                FilledButton(
                  onPressed: () => PermissionsService().openAppSettings(),
                  child: const Text('Open settings'),
                ),
                OutlinedButton(
                  onPressed: _loadData,
                  child: const Text('Try again'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
          if (_blockerOff) ...[
            NoticeCard(
              tone: NoticeTone.danger,
              icon: Icons.shield_outlined,
              title: 'App locking is switched off',
              message:
                  'Android has turned off the Walkies blocker, so your '
                  'locked apps will open. Turn it back on, and stop battery '
                  'saving from closing Walkies so it stays on.',
              actions: [
                FilledButton(
                  onPressed: _appLockerService.openAccessibilitySettings,
                  child: const Text('Turn on'),
                ),
                OutlinedButton(
                  onPressed: _appLockerService.openBatterySettings,
                  child: const Text('Battery settings'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
          _StepsHero(
            steps: _currentSteps,
            goal: goalSteps,
            progress: progress,
            goalMet: goalMet,
          ),
          const SizedBox(height: AppSpacing.gap),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.route_rounded,
                  value: distanceKm.toStringAsFixed(1),
                  unit: 'km',
                  label: 'Distance',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  value: '$_currentStreak',
                  unit: _currentStreak == 1 ? 'day' : 'days',
                  label: 'Streak',
                  accent: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  value: '$activeMinutes',
                  unit: 'min',
                  label: 'Walking',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap),
          AppCard(
            color: AppPalette.sage,
            borderColor: null,
            shadow: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(
                  Icons.lightbulb_outline_rounded,
                  background: AppPalette.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s nudge',
                        style: text.titleSmall!.copyWith(
                          color: AppPalette.forestDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nudge(goalMet, progress),
                        style: text.bodyMedium!.copyWith(
                          color: AppPalette.forestDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          WeeklyStreakWidget(
            dailyGoalsMet: _dailyGoalsMet,
            currentStreak: _currentStreak,
          ),
          const SizedBox(height: AppSpacing.gap),
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AppLockSettingsScreen(),
                ),
              );
            },
            child: Row(
              children: [
                const IconBadge(
                  Icons.lock_outline_rounded,
                  background: AppPalette.terracottaSoft,
                  foreground: Color(0xFF8A4318),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App locks', style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Choose which apps wait until you reach your goal',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _nudge(bool goalMet, double progress) {
    if (goalMet) {
      return 'Goal done. Anything extra today is a bonus for tomorrow\'s you.';
    }
    if (progress >= 0.8) return 'Nearly there. One short walk should do it.';
    if (progress >= 0.5) {
      return 'Over halfway. A lap of the block after your next meal keeps '
          'the momentum going.';
    }
    return 'A brisk 10-minute walk now makes a real dent in your goal.';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _userDisplayName() {
    final email = _supabaseService.currentUserEmail;
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
}

class _StepsHero extends StatelessWidget {
  final int steps;
  final int goal;
  final double progress;
  final bool goalMet;

  const _StepsHero({
    required this.steps,
    required this.goal,
    required this.progress,
    required this.goalMet,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = (goal - steps).clamp(0, goal);
    final digits = steps.clamp(0, 99999).toString().padLeft(5, '0').split('');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.forestSoft, AppPalette.forestDeep],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332D5A4A),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY\'S STEPS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              goalMet
                  ? const Pill(
                      'Apps unlocked',
                      icon: Icons.lock_open_rounded,
                      background: AppPalette.sage,
                    )
                  : Pill(
                      '${formatNumber(remaining)} to unlock',
                      icon: Icons.lock_outline_rounded,
                      background: AppPalette.terracottaSoft,
                      foreground: const Color(0xFF8A4318),
                    ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < digits.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _OdometerDigit(int.parse(digits[i]))),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: goalMet ? AppPalette.sageDeep : AppPalette.terracotta,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(progress * 100).round()}% of your goal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Goal ${formatNumber(goal)}',
                style: text.labelMedium!.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One wheel of the step counter, with the neighbouring digits faded
class _OdometerDigit extends StatelessWidget {
  final int digit;

  const _OdometerDigit(this.digit);

  @override
  Widget build(BuildContext context) {
    TextStyle faded(double size) => TextStyle(
      fontFamily: 'Fraunces',
      fontWeight: FontWeight.w500,
      fontSize: size,
      height: 1,
      color: Colors.white.withValues(alpha: 0.28),
    );
    return Container(
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('${(digit + 9) % 10}', style: faded(14)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$digit',
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                fontSize: 40,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
          Text('${(digit + 1) % 10}', style: faded(14)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final bool accent;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon,
            size: 32,
            background: accent ? AppPalette.terracottaSoft : AppPalette.sage,
            foreground: accent ? const Color(0xFF8A4318) : AppPalette.forest,
          ),
          const SizedBox(height: 12),
          // Shrinks rather than overflowing with large system text sizes
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: text.headlineSmall),
                const SizedBox(width: 3),
                Text(unit, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
