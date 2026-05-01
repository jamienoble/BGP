import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/screens/login_screen.dart';
import 'package:walkies/screens/dashboard_screen.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/screens/settings_screen.dart';
import 'package:walkies/screens/education_screen.dart';
import 'package:walkies/screens/community_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your credentials
  // Replace with your actual Supabase URL and anon key
  await Supabase.initialize(
    url: 'https://cbanimdilwtfmouyfumr.supabase.co', // e.g., 'https://xyzabc.supabase.co'
    anonKey: 'sb_publishable_6a52AMpgt5KIdS3KcGzEcQ_5P212w-l',
  );

  // Sync timezone to native side on app startup
  final appLockerService = AppLockerService();
  final now = DateTime.now();
  final timezone = now.timeZoneOffset.inHours >= 0
      ? 'UTC+${now.timeZoneOffset.inHours}'
      : 'UTC${now.timeZoneOffset.inHours}';
  
  try {
    await appLockerService.syncUserTimezone(timezone);
  } catch (e) {
    print('Error syncing timezone on startup: $e');
  }

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
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D5A4A), // Forest green
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFF8F0), // Warm cream
        ),
        home: const _AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/app_locks': (_) => const AppLockSettingsScreen(),
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

  final List<Widget> _screens = [
    const DashboardScreen(),
    const EducationScreen(),
    const CommunityScreen(),
  ];

  final List<String> _titles = [
    'Walkies Dashboard',
    'Education',
    'Community',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school),
            label: 'Education',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}
