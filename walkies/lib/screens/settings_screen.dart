import 'package:flutter/material.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:walkies/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                final supabaseService = SupabaseService();
                try {
                  await supabaseService.signOut();
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
