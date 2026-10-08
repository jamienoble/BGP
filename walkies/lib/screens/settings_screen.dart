import 'package:flutter/material.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabaseService = SupabaseService();
  String? _preferredName;
  bool _isSavingName = false;
  bool _lockCommunity = false;

  Future<void> _loadCommunityLock() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lockCommunity =
          prefs.getBool(AppConstants.prefCommunityLockedUntilGoal) ?? false;
    });
  }

  Future<void> _setCommunityLock(bool value) async {
    setState(() => _lockCommunity = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefCommunityLockedUntilGoal, value);
  }

  /// Sign out. Settings sits above the main app, so pop back to the root;
  /// the auth wrapper in main.dart then shows the login screen.
  Future<void> _signOut() async {
    try {
      await StepTrackingService().flushToCloud();
      // Locks belong to the account; don't leave them enforced signed out
      await AppLockerService().clearAccessibilityServiceLockedApps();
      await _supabaseService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, step history, goal, '
          'app locks and community posts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabaseService.deleteAccount();
      await AppLockerService().clearAccessibilityServiceLockedApps();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Please try again.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferredName();
    _loadCommunityLock();
  }

  Future<void> _loadPreferredName() async {
    try {
      await _supabaseService.ensureUserProfile();
      final name = await _supabaseService.getPreferredName();
      if (!mounted) return;
      setState(() {
        _preferredName = name;
      });
    } catch (_) {}
  }

  Future<void> _editPreferredName() async {
    final controller = TextEditingController(text: _preferredName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your preferred name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null) return;
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSavingName = true;
    });
    try {
      await _supabaseService.upsertPreferredName(newName);
      if (!mounted) return;
      setState(() {
        _preferredName = newName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferred name updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update name. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Daily Goal Section
          Card(
            margin: const EdgeInsets.all(16.0),
            child: ListTile(
              title: const Text('Daily Step Goal'),
              subtitle: const Text('Set your daily step target'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GoalManagementScreen(),
                  ),
                );
              },
            ),
          ),

          // App Locks Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ListTile(
              title: const Text('App Locks'),
              subtitle: const Text('Manage locked apps'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed('/app_locks');
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: ListTile(
              title: const Text('Preferred Name'),
              subtitle: Text(_preferredName ?? 'Set your display name'),
              trailing: _isSavingName
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isSavingName ? null : _editPreferredName,
            ),
          ),

          const SizedBox(height: 24),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SwitchListTile(
              title: const Text('Lock Community until goal met'),
              subtitle: const Text(
                'Treat the Community tab like a locked app',
              ),
              value: _lockCommunity,
              onChanged: _setCommunityLock,
            ),
          ),
          const SizedBox(height: 24),
          // Account Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Account',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),

          // Sign Out Button
          Card(
            margin: const EdgeInsets.all(16.0),
            child: ListTile(
              title: const Text('Sign Out'),
              leading: const Icon(Icons.logout, color: Colors.red),
              titleTextStyle: const TextStyle(color: Colors.red),
              onTap: _signOut,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ListTile(
              title: const Text('Delete account'),
              subtitle: const Text('Permanently remove your account and data'),
              leading: Icon(Icons.delete_forever, color: Colors.red[700]),
              onTap: _deleteAccount,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
