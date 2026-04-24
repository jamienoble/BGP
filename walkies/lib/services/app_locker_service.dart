import 'package:device_apps/device_apps.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/services/supabase_service.dart';

class AppLockerService {
  static final AppLockerService _instance = AppLockerService._internal();

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
  }

  Future<void> unlockApp(String appLockId) async {
    await _supabaseService.deleteAppLock(appLockId);
  }

  Future<List<AppLock>> getLockedAppsList() async {
    return await _supabaseService.getLockedApps();
  }
}
