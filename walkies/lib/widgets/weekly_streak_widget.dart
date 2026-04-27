import 'package:flutter/material.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

/// Widget to display weekly streak with day indicators
/// Shows M, T, W, T, F, S, S for the current week
/// with visual indicators for whether goals were met
class WeeklyStreakWidget extends StatelessWidget {
  final Map<DateTime, bool> dailyGoalsMet;
  final int currentStreak;

  const WeeklyStreakWidget({
    Key? key,
    required this.dailyGoalsMet,
    required this.currentStreak,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Streak',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.red[600],
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$currentStreak day${currentStreak != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Days grid
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  7,
                  (index) => _DayStreak(
                    label: dayLabels[index],
                    date: weekDays[index],
                    goalMet: dailyGoalsMet[weekDays[index]] ?? false,
                    isToday: _isToday(weekDays[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _getWeekDays() => date_utils.DateUtils.getCurrentWeekDays();

  bool _isToday(DateTime date) => date_utils.DateUtils.isToday(date);
}

/// Individual day streak indicator
class _DayStreak extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool goalMet;
  final bool isToday;

  const _DayStreak({
    required this.label,
    required this.date,
    required this.goalMet,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBackgroundColor(),
            border: isToday
                ? Border.all(color: Colors.deepPurple, width: 2)
                : null,
          ),
          child: Center(
            child: goalMet
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getBackgroundColor() {
    if (goalMet) {
      return Colors.green[600]!;
    }
    if (isToday) {
      return Colors.deepPurple[100]!;
    }
    return Colors.grey[300]!;
  }

  Color _getTextColor() {
    if (isToday) {
      return Colors.deepPurple;
    }
    return Colors.grey[600]!;
  }
}
