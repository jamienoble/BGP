import 'package:device_apps/device_apps.dart';
import 'package:flutter/services.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/services/supabase_service.dart';

class AppLockerService {
  static final AppLockerService _instance = AppLockerService._internal();
  static const platform = MethodChannel('com.example.walkies/app_locking');

  factory AppLockerService() {
    return _instance;
  }

  AppLockerService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  Future<List<Application>> getInstalledApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    );
    return apps;
  }

  Future<bool> isAppLocked(String packageName) async {
    final lockedApps = await _supabaseService.getLockedApps();
    return lockedApps.any((app) => app.appPackageName == packageName);
  }

  Future<bool> canLaunchApp(
    String packageName,
    int currentSteps,
    int dailyGoal,
  ) async {
    final isLocked = await isAppLocked(packageName);
    if (!isLocked) return true;

    // App is locked, check if user has met their step goal
    return currentSteps >= dailyGoal;
  }

  Future<void> lockApp(String packageName, String appName) async {
    await _supabaseService.createAppLock(packageName, appName);
    // Update the accessibility service with the new locked app
    await _updateAccessibilityServiceLockedApps();
  }

  Future<void> unlockApp(String appLockId) async {
    await _supabaseService.deleteAppLock(appLockId);
    // Update the accessibility service with the removed locked app
    await _updateAccessibilityServiceLockedApps();
  }

  Future<List<AppLock>> getLockedAppsList() async {
    return await _supabaseService.getLockedApps();
  }

  /// Update the accessibility service with current locked apps
  Future<void> _updateAccessibilityServiceLockedApps() async {
    try {
      final lockedApps = await getLockedAppsList();
      final packageNames = lockedApps.map((app) => app.appPackageName).toList();

      final result = await platform.invokeMethod<bool>(
        'updateLockedApps',
        {'packages': packageNames},
      );

      if (result == true) {
        print('Accessibility service updated with ${packageNames.length} locked apps');
      }
    } catch (e) {
      print('Error updating accessibility service: $e');
    }
  }

  /// Enable app locking via accessibility service
  Future<bool> enableAppLocking() async {
    try {
      final result = await platform.invokeMethod<bool>('enableAppLocking');
      return result ?? false;
    } catch (e) {
      print('Error enabling app locking: $e');
      return false;
    }
  }

  /// Disable app locking
  Future<bool> disableAppLocking() async {
    try {
      final result = await platform.invokeMethod<bool>('disableAppLocking');
      return result ?? false;
    } catch (e) {
      print('Error disabling app locking: $e');
      return false;
    }
  }

  /// Check if accessibility service is enabled
  Future<bool> isAppLockingEnabled() async {
    try {
      final result = await platform.invokeMethod<bool>('isAppLockingEnabled');
      return result ?? false;
    } catch (e) {
      print('Error checking app locking status: $e');
      return false;
    }
  }

  /// Open accessibility settings
  Future<void> openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }
}
