import 'package:permission_handler/permission_handler.dart' as permission_handler;

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();

  factory PermissionsService() {
    return _instance;
  }

  PermissionsService._internal();

  /// Request step tracking (activity recognition) permission
  Future<bool> requestActivityRecognitionPermission() async {
    final status = await permission_handler.Permission.activityRecognition.request();
    return status.isGranted;
  }

  /// Check if activity recognition permission is granted
  Future<bool> hasActivityRecognitionPermission() async {
    final status = await permission_handler.Permission.activityRecognition.status;
    return status.isGranted;
  }

  /// Request all permissions needed by the app
  Future<Map<permission_handler.Permission, permission_handler.PermissionStatus>> requestAllPermissions() async {
    final permissions = [
      permission_handler.Permission.activityRecognition,
      permission_handler.Permission.notification,
    ];

    return await permissions.request();
  }

  /// Request notification permission (Android 13+, iOS)
  Future<bool> requestNotificationPermission() async {
    final status = await permission_handler.Permission.notification.request();
    return status.isGranted;
  }

  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(permission_handler.Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    await permission_handler.openAppSettings();
  }

  /// Get a user-friendly message for why a permission is needed
  String getPermissionReason(String permissionType) {
    switch (permissionType) {
      case 'activity_recognition':
        return 'This app needs permission to count your steps. Enable in Settings > Permissions > Activity Recognition.';
      case 'body_sensors':
        return 'This app needs permission to access body sensors for accurate step counting.';
      default:
        return 'This app needs additional permissions to function properly.';
    }
  }
}
