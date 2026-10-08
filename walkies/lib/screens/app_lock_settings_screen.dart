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
        appBar: AppBar(title: const Text('Lock Apps')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final apps = _installedApps ?? [];
    final lockedIds = _lockedAppIds ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Lock Apps')),
      body: Column(
        children: [
          // Accessibility Service Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            color: _isAccessibilityServiceEnabled
                ? Colors.green[100]
                : Colors.orange[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAccessibilityServiceEnabled
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _isAccessibilityServiceEnabled
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAccessibilityServiceEnabled
                          ? 'App Locking Active'
                          : 'App Locking Inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isAccessibilityServiceEnabled
                            ? Colors.green[900]
                            : Colors.orange[900],
                      ),
                    ),
                  ],
                ),
                if (_isAccessibilityServiceEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Select apps below to lock until you reach your daily step goal.',
                    style: TextStyle(color: Colors.green[800], fontSize: 12),
                  ),
                ],
                if (!_isAccessibilityServiceEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Enable the Walkies accessibility service to lock social media apps.\n'
                    'If you see "denied access", go to Settings → Apps → Walkies → ⋮ → Allow restricted settings first.',
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                    ),
                    onPressed: () {
                      _appLockerService.openAccessibilitySettings();
                    },
                    child: const Text(
                      'Enable Service',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Show all apps'),
            subtitle: const Text('Lock any app, not just social media'),
            value: _showAllApps,
            onChanged: (value) {
              setState(() {
                _showAllApps = value;
                _isLoading = true;
              });
              _loadData();
            },
          ),
          // Apps List
          Expanded(
            child: apps.isEmpty
                ? Center(
                    child: Text(
                      _showAllApps
                          ? 'No apps found.'
                          : 'No supported social media apps found.\n'
                              'Turn on "Show all apps" to lock any app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final isLocked = lockedIds.contains(app.packageName);
                      final isSaving = _savingPackages.contains(app.packageName);

                      return ListTile(
                        leading: app.icon != null
                            ? Image.memory(app.icon!, width: 40, height: 40)
                            : const Icon(Icons.apps),
                        title: Text(app.appName),
                        trailing: Switch(
                          value: isLocked,
                          onChanged: isSaving ? null : (_) => _toggleAppLock(app),
                        ),
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }
}
