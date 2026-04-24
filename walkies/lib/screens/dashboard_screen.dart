import 'package:flutter/material.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabaseService = SupabaseService();
  final _stepTrackingService = StepTrackingService();

  StepGoal? _stepGoal;
  int _currentSteps = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _stepTrackingService.initialize();

      final goal = await _supabaseService.getStepGoal();
      final today = await _supabaseService.getTodaySteps();

      setState(() {
        _stepGoal = goal;
        _currentSteps = today?.steps ?? 0;
        _isLoading = false;
      });

      // Listen to step updates
      _stepTrackingService.stepCountStream.listen((event) {
        if (mounted) {
          setState(() {
            _currentSteps = event.steps;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final goalSteps = _stepGoal?.dailySteps ?? 0;
    final progress = goalSteps > 0 ? _currentSteps / goalSteps : 0.0;
    final goalMet = _currentSteps >= goalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walkies Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Steps Progress Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Today\'s Steps', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 8,
                            color: goalMet ? Colors.green : Colors.orange,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_currentSteps',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'of ${goalSteps} steps',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (goalMet)
                      const Chip(
                        label: Text('Goal Met! 🎉'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      Chip(
                        label: Text('${goalSteps - _currentSteps} steps to go'),
                        backgroundColor: Colors.orange,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Lock Status
            Card(
              elevation: 4,
              child: ListTile(
                title: const Text('App Locks Active'),
                subtitle: const Text('Tap to manage locked apps'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppLockSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Goal Management
            Card(
              elevation: 4,
              child: ListTile(
                title: const Text('Daily Goal'),
                subtitle: Text('${goalSteps} steps'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GoalManagementScreen(),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
