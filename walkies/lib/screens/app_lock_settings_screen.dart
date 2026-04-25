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
  bool _isAccessibilityServiceEnabled = false;

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
      final isServiceEnabled = await _appLockerService.isAppLockingEnabled();

      setState(() {
        _installedApps = apps;
        _lockedAppIds = lockedIds;
        _isAccessibilityServiceEnabled = isServiceEnabled;
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
    // First check if accessibility service is enabled
    if (!_isAccessibilityServiceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable Accessibility Service'),
            content: const Text(
              'To lock apps, Walkies needs its Accessibility Service enabled.\n\n'
              '⚠️ If you see "App was denied access" or "Controlled by restricted setting":\n\n'
              '1. Go to Settings → Apps → Walkies\n'
              '2. Tap the ⋮ menu (top right)\n'
              '3. Tap "Allow restricted settings"\n'
              '4. Then return here and tap Enable again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _appLockerService.openAccessibilitySettings();
                },
                child: const Text('Enable'),
              ),
            ],
          ),
        );
      }
      return;
    }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
      body: Column(
        children: [
          // Accessibility Service Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            color: _isAccessibilityServiceEnabled
                ? Colors.green[100]
                : Colors.orange[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAccessibilityServiceEnabled
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _isAccessibilityServiceEnabled
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAccessibilityServiceEnabled
                          ? 'App Locking Active'
                          : 'App Locking Inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isAccessibilityServiceEnabled
                            ? Colors.green[900]
                            : Colors.orange[900],
                      ),
                    ),
                  ],
                ),
                if (!_isAccessibilityServiceEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Enable the Walkies accessibility service to lock apps.\n'
                    'If you see "denied access", go to Settings → Apps → Walkies → ⋮ → Allow restricted settings first.',
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                    ),
                    onPressed: () {
                      _appLockerService.openAccessibilitySettings();
                    },
                    child: const Text(
                      'Enable Service',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Apps List
          Expanded(
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final isLocked = lockedIds.contains(app.packageName);

                return ListTile(
                  leading: app is ApplicationWithIcon
                      ? Image.memory(app.icon, width: 40, height: 40)
                      : const Icon(Icons.apps),
                  title: Text(app.appName),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Switch(
                    value: isLocked,
                    onChanged: (_) => _toggleAppLock(app),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
