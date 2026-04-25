import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Skip Firebase initialization on web (not needed for this app)
    if (kIsWeb) {
      await _initializeLocalNotifications();
      return;
    }

    // Request notification permissions (mobile only)
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      sound: true,
    );

    await _initializeLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    // Handle background message
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(initSettings);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('Handling background message: ${message.messageId}');
  }

  void _handleMessage(RemoteMessage message) {
    print('Message received: ${message.notification?.title}');

    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
    );
  }

  /// Show a local notification (used for push notifications when app is in foreground)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'walkies_channel',
          'Walkies Notifications',
          channelDescription: 'Notifications for Walkies app',
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
      DateTime.now().hashCode,
      title,
      body,
      details,
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
      title: '🎯 Goal Almost Complete!',
      body: 'You\'re $percentage% done! Only $stepsRemaining steps to go.',
    );
  }

  /// Send a local notification for goal completion
  Future<void> sendGoalCompletedNotification() async {
    await _showLocalNotification(
      title: '🎉 Daily Goal Completed!',
      body:
          'Congratulations! You\'ve reached your daily step goal. Apps are now unlocked!',
    );
  }

  /// Send a local notification for app unlock
  Future<void> sendAppUnlockedNotification(String appName) async {
    await _showLocalNotification(
      title: '✅ App Unlocked',
      body: '$appName is now unlocked! You met your daily step goal.',
    );
  }
}
