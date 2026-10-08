import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/models/installed_app.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

class AppLockerService {
  static final AppLockerService _instance = AppLockerService._internal();
  static const platform = MethodChannel('com.example.walkies/app_locking');

  // Common social media app package names
  static const Set<String> _socialMediaPackages = {
    // Facebook
    'com.facebook.katana',
    'com.facebook.lite',
    'com.facebook.orca', // Messenger
    
    // Instagram
    'com.instagram.android',
    'com.instagram.lite',
    
    // Twitter / X
    'com.twitter.android',

    // TikTok
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
    
    // Snapchat
    'com.snapchat.android',
    
    // WhatsApp
    'com.whatsapp',
    'com.whatsapp.w4b',
    
    // Telegram
    'org.telegram.messenger',
    'org.telegram.messenger.web',
    
    // LinkedIn
    'com.linkedin.android',
    
    // Reddit
    'com.reddit.frontpage',
    
    // Viber
    'com.viber.voip',
    
    // WeChat
    'com.tencent.mm',
    
    // QQ
    'com.tencent.mobileqq',
    
    // Discord
    'com.discord',
    
    // Nextdoor
    'com.nextdoor',
    
    // BeReal
    'com.bereal.ft',
    
    // Pinterest
    'com.pinterest',
    
    // Mastodon
    'org.joinmastodon.android',

    // Bluesky
    'xyz.blueskyweb.app',
    
    // YouTube (video streaming/social)
    'com.google.android.youtube',
    'com.google.android.youtube.tv',
    
    // Twitch
    'tv.twitch.android.app',
    
    // Threads
    'com.instagram.barcelona',
  };

  factory AppLockerService() {
    return _instance;
  }

  AppLockerService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Launchable apps on the device, sorted by name. Pass [packages] to
  /// only load those (icons are only rendered for the apps returned).
  Future<List<InstalledApp>> getInstalledApps({Set<String>? packages}) async {
    final result = await platform.invokeListMethod<Map<dynamic, dynamic>>(
      'getInstalledApps',
      {'packages': packages?.toList()},
    );
    return (result ?? []).map(InstalledApp.fromMap).toList();
  }

  /// Installed social media apps, plus any [alsoInclude] packages
  /// (e.g. other apps the user has already locked)
  Future<List<InstalledApp>> getSocialMediaApps({
    Set<String> alsoInclude = const {},
  }) {
    return getInstalledApps(
      packages: {..._socialMediaPackages, ...alsoInclude},
    );
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

  /// Sync cloud-locked apps down to native accessibility service.
  Future<void> syncLockedAppsToAccessibilityService() async {
    await _updateAccessibilityServiceLockedApps();
  }

  /// Keep native step/goal prefs in sync for accessibility checks.
  Future<void> syncNativeStepGoalPrefs({
    required int dailyGoal,
    required int todaySteps,
  }) async {
    try {
      await platform.invokeMethod<bool>('syncStepGoalData', {
        'dailyGoal': dailyGoal,
        'todaySteps': todaySteps,
        'date': date_utils.DateUtils.todayDateString(),
      });
    } catch (_) {
      // Ignore if native bridge is temporarily unavailable.
    }
  }

  /// Remove every lock from the native blocker (e.g. on sign-out)
  Future<void> clearAccessibilityServiceLockedApps() async {
    try {
      await platform.invokeMethod<bool>(
        'updateLockedApps',
        {'packages': <String>[]},
      );
    } catch (e) {
      debugPrint('Error clearing locked apps: $e');
    }
  }

  /// Update the accessibility service with current locked apps
  Future<void> _updateAccessibilityServiceLockedApps() async {
    try {
      final lockedApps = await getLockedAppsList();
      final packageNames = lockedApps.map((app) => app.appPackageName).toList();

      await platform.invokeMethod<bool>(
        'updateLockedApps',
        {'packages': packageNames},
      );
    } catch (e) {
      debugPrint('Error updating accessibility service: $e');
    }
  }

  /// Enable app locking via accessibility service
  Future<bool> enableAppLocking() async {
    try {
      final result = await platform.invokeMethod<bool>('enableAppLocking');
      return result ?? false;
    } catch (e) {
      debugPrint('Error enabling app locking: $e');
      return false;
    }
  }

  /// Disable app locking
  Future<bool> disableAppLocking() async {
    try {
      final result = await platform.invokeMethod<bool>('disableAppLocking');
      return result ?? false;
    } catch (e) {
      debugPrint('Error disabling app locking: $e');
      return false;
    }
  }

  /// Check if accessibility service is enabled
  Future<bool> isAppLockingEnabled() async {
    try {
      final result = await platform.invokeMethod<bool>('isAppLockingEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking app locking status: $e');
      return false;
    }
  }

  /// Open accessibility settings
  Future<void> openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
    }
  }
}
