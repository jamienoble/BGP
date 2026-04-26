import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/supabase_service.dart';

class GoalManagementScreen extends StatefulWidget {
  const GoalManagementScreen({Key? key}) : super(key: key);

  @override
  State<GoalManagementScreen> createState() => _GoalManagementScreenState();
}

class _GoalManagementScreenState extends State<GoalManagementScreen> {
  final _supabaseService = SupabaseService();
  final _goalController = TextEditingController();

  int? _currentGoal;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    try {
      final goal = await _supabaseService.getStepGoal();
      setState(() {
        _currentGoal = goal?.dailySteps ?? 5000;
        _goalController.text = _currentGoal.toString();
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading goal: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGoal() async {
    final newGoal = int.tryParse(_goalController.text);
    if (newGoal == null || newGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid step count')),
      );
      return;
    }
    if (_currentGoal != null && newGoal < _currentGoal!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Goal cannot be reduced below your current goal ($_currentGoal).',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabaseService.createOrUpdateStepGoal(newGoal);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_goal', newGoal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your goal. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Step Goal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Set your daily step goal',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps per day',
                border: OutlineInputBorder(),
                prefixText: '🚶 ',
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGoal,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Goal'),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• The WHO recommends 7,000+ steps daily'),
                    Text('• Adjust based on your current fitness level'),
                    Text('• Apps locked until you reach your goal'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
