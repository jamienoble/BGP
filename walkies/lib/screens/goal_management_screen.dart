import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/goal_rules.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
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
        _goalController.text = formatNumber(_currentGoal!);
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
      final previousGoal = _currentGoal;
      await _supabaseService.createOrUpdateStepGoal(newGoal);
      if (previousGoal != null && newGoal != previousGoal) {
        await GoalRules.pinForToday(previousGoal);
      }
      final todayGoal = await GoalRules.effectiveGoal(newGoal);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.prefDailyGoal, todayGoal);
      // Push today's goal to the app blocker straight away
      await AppLockerService().syncNativeStepGoalPrefs(
        dailyGoal: todayGoal,
        todaySteps: StepTrackingService().todaySteps,
      );
      if (resetStreak) {
        await _resetStreak();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resetStreak
                  ? 'New goal starts tomorrow. Your streak has been reset.'
                  : 'New goal starts tomorrow.',
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
    final newGoal = _parseGoal(_goalController.text);
    if (newGoal == null || newGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid step count')),
      );
      return;
    }
    if (newGoal == _currentGoal) {
      Navigator.of(context).pop();
      return;
    }
    // Any change applies from tomorrow; today keeps the goal already in force
    final todayGoal = await GoalRules.effectiveGoal(_currentGoal);
    if (!mounted) return;
    final isGoalReduced = _currentGoal != null && newGoal < _currentGoal!;
    if (isGoalReduced) {
      final shouldReset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lower your goal?'),
          content: Text(
            'Your new goal of $newGoal steps starts tomorrow. '
            'Today\'s goal stays at $todayGoal steps.\n\n'
            'Lowering your goal also resets your streak to 0. Continue?',
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
          content: Text(
            'Your new goal of $newGoal steps starts tomorrow. '
            'Today\'s goal stays at $todayGoal steps.',
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

  /// Accepts "7,000" as well as "7000"
  int? _parseGoal(String value) => int.tryParse(value.replaceAll(RegExp(r'[,\s]'), ''));

  int get _draftGoal => _parseGoal(_goalController.text) ?? 0;

  void _setDraft(int value) {
    setState(() {
      _goalController.text = formatNumber(value.clamp(500, 50000));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final text = Theme.of(context).textTheme;
    const presets = [5000, 7000, 8000, 10000];

    return Scaffold(
      appBar: AppBar(title: const Text('Daily goal')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text('How far today?', style: text.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Your apps unlock when you reach this many steps. Changes start '
            'tomorrow, so today\'s goal stays as it is.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 22),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    _StepButton(
                      icon: Icons.remove_rounded,
                      onPressed: _isSaving ? null : () => _setDraft(_draftGoal - 500),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _goalController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: text.displayMedium!.copyWith(color: AppPalette.forestDeep),
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add_rounded,
                      onPressed: _isSaving ? null : () => _setDraft(_draftGoal + 500),
                    ),
                  ],
                ),
                Text('steps a day', style: text.bodySmall),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in presets)
                      ChoiceChip(
                        label: Text(formatNumber(p)),
                        selected: _draftGoal == p,
                        onSelected: _isSaving ? null : (_) => _setDraft(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _isSaving ? null : _saveGoal,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save goal'),
          ),
          const SizedBox(height: 22),
          const NoticeCard(
            tone: NoticeTone.info,
            icon: Icons.tips_and_updates_outlined,
            title: 'Picking a goal',
            message: 'Research suggests around 7,000 steps a day brings many '
                'of the health benefits of walking. Start near what you '
                'already do and build up; a goal you can hit most days '
                'beats one you rarely reach.',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppPalette.sage,
        foregroundColor: AppPalette.forest,
        fixedSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}
