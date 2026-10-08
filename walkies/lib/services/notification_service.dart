import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walkies/constants/app_constants.dart';

/// Local notifications for goal progress. No push service is used.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _override ?? _instance;

  static NotificationService? _override;

  /// Replace the shared instance. For tests and screenshot previews only.
  @visibleForTesting
  static set debugOverride(NotificationService? value) => _override = value;

  /// For test fakes that subclass this service.
  @visibleForTesting
  NotificationService.forTesting();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Show a local notification. [id] is fixed per notification type so a
  /// repeat replaces the earlier one instead of stacking.
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Send a local notification for goal near completion
  /// Call this when user reaches ~80% of their daily goal
  Future<void> sendGoalNearCompletionNotification({
    required int currentSteps,
    required int goalSteps,
    required int stepsRemaining,
  }) async {
    final percentage = ((currentSteps / goalSteps) * 100).toStringAsFixed(0);

    await _showLocalNotification(
      id: 1,
      title: '🎯 Goal Almost Complete!',
      body: 'You\'re $percentage% done! Only $stepsRemaining steps to go.',
    );
  }

  /// Send a local notification for goal completion
  Future<void> sendGoalCompletedNotification() async {
    await _showLocalNotification(
      id: 2,
      title: '🎉 Daily Goal Completed!',
      body:
          'Congratulations! You\'ve reached your daily step goal. Apps are now unlocked!',
    );
  }

  /// Send a local notification for app unlock
  Future<void> sendAppUnlockedNotification(String appName) async {
    await _showLocalNotification(
      id: 3,
      title: '✅ App Unlocked',
      body: '$appName is now unlocked! You met your daily step goal.',
    );
  }
}
