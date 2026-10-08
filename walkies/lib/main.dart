import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/screens/login_screen.dart';
import 'package:walkies/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your credentials
  // Replace with your actual Supabase URL and anon key
  await Supabase.initialize(
    url: 'https://cbanimdilwtfmouyfumr.supabase.co', // e.g., 'https://xyzabc.supabase.co'
    anonKey: 'sb_publishable_6a52AMpgt5KIdS3KcGzEcQ_5P212w-l',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walkies - App Locker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Login vs dashboard is decided only by the auth state below, so
      // screens never navigate between the two themselves
      home: const _AuthWrapper(),
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
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
