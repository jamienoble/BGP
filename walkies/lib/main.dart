import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/screens/login_screen.dart';
import 'package:walkies/screens/dashboard_screen.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/screens/settings_screen.dart';
import 'package:walkies/screens/education_screen.dart';
import 'package:walkies/screens/community_screen.dart';
import 'package:walkies/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The publishable (anon) key is meant to ship in the app; data is
  // protected by row level security in Supabase
  await Supabase.initialize(
    url: 'https://cbanimdilwtfmouyfumr.supabase.co',
    anonKey: 'sb_publishable_6a52AMpgt5KIdS3KcGzEcQ_5P212w-l',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walkies',
      theme: AppTheme.light(),
      // Login vs main app is decided only by the auth state below, so
      // screens never navigate between the two themselves
      home: const _AuthWrapper(),
      routes: {
        '/app_locks': (_) => const AppLockSettingsScreen(),
      },
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  final _supabaseService = SupabaseService();
  StreamSubscription<AuthState>? _recoverySubscription;

  @override
  void initState() {
    super.initState();
    // A password reset link signs the user in with a recovery session;
    // ask for the new password straight away
    _recoverySubscription =
        _supabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery && mounted) {
        _showSetPasswordDialog();
      }
    });
  }

  @override
  void dispose() {
    _recoverySubscription?.cancel();
    super.dispose();
  }

  Future<void> _showSetPasswordDialog() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set a new password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPassword == null || newPassword.isEmpty) return;

    try {
      await _supabaseService.updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update password. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data?.session != null) {
          return const MainTabNavigator();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({Key? key}) : super(key: key);

  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _currentIndex = 0;

  // Kept alive in an IndexedStack so switching tabs doesn't rebuild
  // each screen (and re-run its loading and listeners)
  final List<Widget> _screens = const [
    DashboardScreen(),
    EducationScreen(),
    CommunityScreen(),
  ];

  final List<String> _titles = const [
    'Walkies',
    'Learn',
    'Community',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: _currentIndex == 0
            ? const _BrandMark()
            : Text(_titles[_currentIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                backgroundColor: AppPalette.white,
                side: const BorderSide(color: AppPalette.line),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.line)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_walk_outlined),
              selectedIcon: Icon(Icons.directions_walk_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Community',
            ),
          ],
        ),
      ),
    );
  }
}

/// App name with a small walking mark, for the Today tab
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppPalette.forest,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_walk_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Walkies'),
      ],
    );
  }
}
