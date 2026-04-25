import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();

  factory PermissionsService() {
    return _instance;
  }

  PermissionsService._internal();

  /// Request step tracking (activity recognition) permission
  Future<bool> requestActivityRecognitionPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  /// Check if activity recognition permission is granted
  Future<bool> hasActivityRecognitionPermission() async {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  /// Request all permissions needed by the app
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = [
      Permission.activityRecognition,
    ];

    return await permissions.request();
  }

  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    openAppSettings();
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
