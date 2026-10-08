import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:walkies/models/installed_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/goal_rules.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen>
    with WidgetsBindingObserver {
  final _appLockerService = AppLockerService();
  final _supabaseService = SupabaseService();

  List<InstalledApp>? _installedApps;
  bool _showAllApps = false;
  List<String>? _lockedAppIds;
  final Set<String> _savingPackages = {};
  bool _isLoading = true;
  bool _isAccessibilityServiceEnabled = false;
  bool _goalMetToday = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefStreakDaysMet, jsonEncode(<String, bool>{}));
    await prefs.setInt(AppConstants.prefStreakCurrent, 0);
    await prefs.setString(
      AppConstants.prefStreakResetDate,
      date_utils.DateUtils.todayDateString(),
    );
  }

  Future<void> _loadData() async {
    try {
      final lockedApps = await _supabaseService.getLockedApps();
      final lockedIds = lockedApps.map((app) => app.appPackageName).toList();
      // Social media apps by default; anything already locked always shows
      final apps = _showAllApps
          ? await _appLockerService.getInstalledApps()
          : await _appLockerService.getSocialMediaApps(
              alsoInclude: lockedIds.toSet(),
            );
      final isServiceEnabled = await _appLockerService.isAppLockingEnabled();
      final stepGoal = await _supabaseService.getStepGoal();
      final todaySteps = await _supabaseService.getTodaySteps();

      final dailyGoal = await GoalRules.effectiveGoal(stepGoal?.dailySteps);
      // The cloud count can lag the local one (e.g. after an offline sync),
      // so never send a lower value than the local tracker has
      final steps = max(StepTrackingService().todaySteps, todaySteps?.steps ?? 0);

      await _appLockerService.syncNativeStepGoalPrefs(
        dailyGoal: dailyGoal,
        todaySteps: steps,
      );
      
      // Force refresh locked apps to accessibility service
      // This catches any day resets that may have happened while app was closed
      await _appLockerService.syncLockedAppsToAccessibilityService();

      if (!mounted) return;
      setState(() {
        _installedApps = apps;
        _lockedAppIds = lockedIds;
        _isAccessibilityServiceEnabled = isServiceEnabled;
        _goalMetToday = steps >= dailyGoal;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load app locks. Pull to refresh and try again.'),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAppLock(InstalledApp app) async {
    // First check if accessibility service is enabled
    if (!_isAccessibilityServiceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable Accessibility Service'),
            content: const Text(
              'To lock apps, Walkies needs its Accessibility Service enabled.\n\n'
              '⚠️ If you see "App was denied access" or "Controlled by restricted setting":\n\n'
              '1. Go to Settings → Apps → Walkies\n'
              '2. Tap the ⋮ menu (top right)\n'
              '3. Tap "Allow restricted settings"\n'
              '4. Then return here and tap Enable again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _appLockerService.openAccessibilitySettings();
                },
                child: const Text('Enable'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final packageName = app.packageName;
    final isCurrentlyLocked = _lockedAppIds?.contains(packageName) ?? false;
    if (_savingPackages.contains(packageName)) return;
    // Removing a lock only costs the streak while it is still enforcing today
    final resetsStreak = isCurrentlyLocked && !_goalMetToday;
    if (resetsStreak) {
      final shouldUnlock = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset streak?'),
          content: Text(
            'Unlocking ${app.appName} will reset your streak to 0. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (shouldUnlock != true) {
        return;
      }
    }

    setState(() {
      _savingPackages.add(packageName);
      final current = _lockedAppIds ?? <String>[];
      if (isCurrentlyLocked) {
        current.remove(packageName);
      } else {
        current.add(packageName);
      }
      _lockedAppIds = List<String>.from(current);
    });

    try {
      if (isCurrentlyLocked) {
        final lockedApps = await _supabaseService.getLockedApps();
        final appLock = lockedApps.firstWhere(
          (lock) => lock.appPackageName == packageName,
        );
        await _appLockerService.unlockApp(appLock.id);
        if (resetsStreak) {
          await _resetStreak();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resetsStreak
                    ? 'App unlocked. Your streak has been reset.'
                    : 'App unlocked.',
              ),
            ),
          );
        }
      } else {
        final appName = app.appName;
        await _appLockerService.lockApp(packageName, appName);
      }
    } catch (e) {
      final current = _lockedAppIds ?? <String>[];
      if (isCurrentlyLocked) {
        current.add(packageName);
      } else {
        current.remove(packageName);
      }
      if (mounted) {
        setState(() {
          _lockedAppIds = List<String>.from(current);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update app lock. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPackages.remove(packageName);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('App locks')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final text = Theme.of(context).textTheme;
    final apps = _installedApps ?? [];
    final lockedIds = _lockedAppIds ?? [];
    final lockedCount = apps.where((a) => lockedIds.contains(a.packageName)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('App locks')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text('Choose what waits', style: text.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Locked apps open again as soon as you reach today\'s step goal.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (_isAccessibilityServiceEnabled)
            NoticeCard(
              tone: NoticeTone.success,
              icon: Icons.verified_user_outlined,
              title: 'App locking is on',
              message: lockedCount == 0
                  ? 'Switch on the apps you want to lock below.'
                  : '$lockedCount ${lockedCount == 1 ? 'app is' : 'apps are'} '
                      'locked until you reach your goal.',
            )
          else
            NoticeCard(
              tone: NoticeTone.warning,
              icon: Icons.shield_outlined,
              title: 'Turn on app locking',
              message: 'Walkies needs its accessibility service to lock apps. '
                  'If Android says "restricted setting", open Settings > Apps > '
                  'Walkies > ⋮ > Allow restricted settings first.',
              actions: [
                FilledButton(
                  onPressed: _appLockerService.openAccessibilitySettings,
                  child: const Text('Turn on'),
                ),
              ],
            ),
          const SizedBox(height: 20),
          SectionLabel(
            _showAllApps ? 'All apps' : 'Social media',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show all', style: text.bodySmall),
                const SizedBox(width: 6),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _showAllApps,
                    onChanged: (value) {
                      setState(() {
                        _showAllApps = value;
                        _isLoading = true;
                      });
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (apps.isEmpty)
            EmptyState(
              icon: Icons.apps_rounded,
              title: _showAllApps ? 'No apps found' : 'No social apps found',
              message: _showAllApps
                  ? null
                  : 'Turn on "Show all" to lock any app on your phone.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < apps.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    _AppRow(
                      app: apps[i],
                      locked: lockedIds.contains(apps[i].packageName),
                      saving: _savingPackages.contains(apps[i].packageName),
                      onToggle: () => _toggleAppLock(apps[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final InstalledApp app;
  final bool locked;
  final bool saving;
  final VoidCallback onToggle;

  const _AppRow({
    required this.app,
    required this.locked,
    required this.saving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: saving ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 42,
                height: 42,
                child: app.icon != null
                    ? Image.memory(app.icon!, fit: BoxFit.cover)
                    : ArtworkPlaceholder(
                        seed: app.packageName,
                        icon: Icons.apps_rounded,
                        iconSize: 22,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.appName, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 13,
                        color: locked ? AppPalette.terracotta : AppPalette.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locked ? 'Locked until goal' : 'Always available',
                        style: text.bodySmall!.copyWith(
                          color: locked ? const Color(0xFFB4532A) : AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(value: locked, onChanged: saving ? null : (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}
