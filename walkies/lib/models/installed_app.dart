import 'dart:typed_data';

/// A launchable app on the device, as reported by the native side.
class InstalledApp {
  final String packageName;
  final String appName;
  final Uint8List? icon;

  InstalledApp({
    required this.packageName,
    required this.appName,
    this.icon,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      icon: map['icon'] as Uint8List?,
    );
  }
}
