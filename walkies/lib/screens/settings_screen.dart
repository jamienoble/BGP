import 'package:flutter/material.dart';
import 'package:walkies/screens/goal_management_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPreferredName();
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
              onTap: () async {
                try {
                  await _supabaseService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
