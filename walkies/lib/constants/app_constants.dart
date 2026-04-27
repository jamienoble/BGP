/// Application-wide constants for Walkies
class AppConstants {
  // Default values
  static const int defaultDailyStepGoal = 7000;
  static const double notificationThresholdPercent = 80.0;
  static const double maxStepsPerSecond = 4.0;
  static const int maxStepsValue = 999999;

  // SharedPreferences keys for step tracking
  static const String prefStepBaselineValue = 'step_baseline_value';
  static const String prefStepBaselineDate = 'step_baseline_date';
  static const String prefStepAppInstallBaseline = 'step_app_install_baseline';
  static const String prefTodaySteps = 'today_steps';
  static const String prefDailyGoal = 'daily_goal';

  // SharedPreferences keys for streak tracking
  static const String prefStreakDaysMet = 'streak_days_met_v1';
  static const String prefStreakCurrent = 'streak_current_v1';
  static const String prefStreakResetDate = 'streak_reset_date_v1';
  static const String prefLastNotificationResetDate = 'last_notification_reset_date';

  // Notification channel
  static const String notificationChannelId = 'walkies_channel';
  static const String notificationChannelName = 'Walkies Notifications';
  static const String notificationChannelDescription =
      'Notifications for Walkies app';

  // Deep link
  static const String deepLinkCallbackUrl =
      'com.example.walkies://login-callback';

  // Error messages
  static const String errorActivityPermissionDenied =
      'Activity recognition permission denied. Please grant it in Settings.';
  static const String errorStepSensorFailed =
      'Failed to access step sensor';
  static const String errorInitializationFailed =
      'Failed to initialize step tracking';
  static const String errorAuthenticationFailed =
      'Authentication failed. Please try again.';
  static const String errorAccessibilityServiceRequired =
      'Walkies needs its Accessibility Service enabled to lock apps.';

  // Route names
  static const String routeLogin = '/login';
  static const String routeDashboard = '/dashboard';

  // Duration constants
  static const Duration retryInitialDelay = Duration(milliseconds: 500);
  static const int maxRetries = 3;
  static const int dayHistoryLimit = 35;
  static const int stepsHistoryDays = 6;
}
