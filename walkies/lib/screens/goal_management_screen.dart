import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

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
        _currentGoal = goal?.dailySteps ?? AppConstants.defaultDailyStepGoal;
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

  Future<void> _resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefStreakDaysMet, jsonEncode(<String, bool>{}));
    await prefs.setInt(AppConstants.prefStreakCurrent, 0);
    await prefs.setString(
      AppConstants.prefStreakResetDate,
      date_utils.DateUtils.todayDateString(),
    );
  }

  Future<void> _persistGoal(int newGoal, {required bool resetStreak}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _supabaseService.createOrUpdateStepGoal(newGoal);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.prefDailyGoal, newGoal);
      if (resetStreak) {
        await _resetStreak();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resetStreak
                  ? 'Goal updated. Your streak has been reset.'
                  : 'Goal updated successfully',
            ),
          ),
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

  Future<void> _saveGoal() async {
    final newGoal = int.tryParse(_goalController.text);
    if (newGoal == null || newGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid step count')),
      );
      return;
    }
    final isGoalReduced = _currentGoal != null && newGoal < _currentGoal!;
    if (isGoalReduced) {
      final shouldReset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset streak?'),
          content: Text(
            'Reducing your goal from ${_currentGoal!} to $newGoal '
            'will reset your streak to 0. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (shouldReset != true) {
        return;
      }
      await _persistGoal(newGoal, resetStreak: true);
      return;
    }

    // Check if goal is being increased
    final isGoalIncreased = _currentGoal != null && newGoal > _currentGoal!;
    if (isGoalIncreased) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Goal Change Notice'),
          content: const Text(
            'Your increased goal will take effect tomorrow. '
            'Any locked apps will remain unlocked for the rest of today. '
            'The new goal will apply starting at midnight.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

    await _persistGoal(newGoal, resetStreak: false);
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
