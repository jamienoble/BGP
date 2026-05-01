import 'package:device_apps/device_apps.dart';
import 'package:flutter/services.dart';
import 'package:walkies/models/app_lock.dart';
import 'package:walkies/services/supabase_service.dart';

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
    'com.x.android',
    
    // TikTok
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.tiktok',
    
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
    'com.bereal.io',
    
    // Pinterest
    'com.pinterest',
    
    // Mastodon
    'org.joinmastodon.android',
    'sh.gab.messenger',
    
    // Bluesky
    'xyz.blusky',
    
    // YouTube (video streaming/social)
    'com.google.android.youtube',
    'com.google.android.youtube.tv',
    
    // Twitch
    'tv.twitch.android.app',
    
    // Threads
    'com.instagram.threads',
  };

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

  /// Get only social media apps that are installed
  Future<List<Application>> getSocialMediaApps() async {
    final allApps = await getInstalledApps();
    return allApps
        .where((app) => _socialMediaPackages.contains(app.packageName))
        .toList();
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
    String? timezone,
  }) async {
    try {
      // Use provided timezone or get device timezone
      final tz = timezone ?? 'UTC';
      await platform.invokeMethod<bool>('syncStepGoalData', {
        'dailyGoal': dailyGoal,
        'todaySteps': todaySteps,
        'timezone': tz,
      });
    } catch (_) {
      // Ignore if native bridge is temporarily unavailable.
    }
  }

  /// Sync user's timezone to native side for proper midnight resets
  /// Call this once at app startup or when user changes their timezone
  Future<bool> syncUserTimezone(String timezone) async {
    try {
      final result = await platform.invokeMethod<bool>('syncUserTimezone', {
        'timezone': timezone,
      });
      return result ?? false;
    } catch (e) {
      print('Error syncing timezone: $e');
      return false;
    }
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
