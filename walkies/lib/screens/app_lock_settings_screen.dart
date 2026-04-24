import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/supabase_service.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _appLockerService = AppLockerService();
  final _supabaseService = SupabaseService();

  List<Application>? _installedApps;
  List<String>? _lockedAppIds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apps = await _appLockerService.getInstalledApps();
      final lockedApps = await _supabaseService.getLockedApps();
      final lockedIds = lockedApps.map((app) => app.appPackageName).toList();

      setState(() {
        _installedApps = apps;
        _lockedAppIds = lockedIds;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppLock(Application app) async {
    final packageName = app.packageName;
    final isCurrentlyLocked = _lockedAppIds?.contains(packageName) ?? false;

    try {
      if (isCurrentlyLocked) {
        final lockedApps = await _supabaseService.getLockedApps();
        final appLock = lockedApps.firstWhere(
          (lock) => lock.appPackageName == packageName,
        );
        await _appLockerService.unlockApp(appLock.id);
      } else {
        final appName = app.appName;
        await _appLockerService.lockApp(packageName, appName);
      }

      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lock Apps')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final apps = _installedApps ?? [];
    final lockedIds = _lockedAppIds ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Lock Apps')),
      body: ListView.builder(
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          final isLocked = lockedIds.contains(app.packageName);

          return ListTile(
            leading: app is ApplicationWithIcon
                ? Image.memory(app.icon, width: 40, height: 40)
                : const Icon(Icons.apps),
            title: Text(app.appName),
            subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Switch(
              value: isLocked,
              onChanged: (_) => _toggleAppLock(app),
            ),
          );
        },
      ),
    );
  }
}
