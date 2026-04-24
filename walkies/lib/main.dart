import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/screens/login_screen.dart';
import 'package:walkies/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your credentials
  // Replace with your actual Supabase URL and anon key
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
    return MultiProvider(
      providers: [
        Provider<SupabaseService>(create: (_) => SupabaseService()),
        Provider<StepTrackingService>(create: (_) => StepTrackingService()),
      ],
      child: MaterialApp(
        title: 'Walkies - App Locker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();
    
    return StreamBuilder<AuthState>(
      stream: supabaseService.client.auth.onAuthStateChange,
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
