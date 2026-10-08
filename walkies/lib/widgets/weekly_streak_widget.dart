import 'package:flutter/material.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;
import 'package:walkies/widgets/ui.dart';

/// This week (Monday to Sunday) with a mark for each day the goal was met,
/// plus the current streak.
class WeeklyStreakWidget extends StatelessWidget {
  final Map<DateTime, bool> dailyGoalsMet;
  final int currentStreak;

  const WeeklyStreakWidget({
    super.key,
    required this.dailyGoalsMet,
    required this.currentStreak,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = date_utils.DateUtils.getCurrentWeekDays();
    final today = date_utils.DateUtils.getDayStart(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('This week', style: text.titleLarge)),
              Pill(
                '$currentStreak-day streak',
                icon: Icons.local_fire_department_rounded,
                background: AppPalette.terracottaSoft,
                foreground: const Color(0xFF8A4318),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _Day(
                  label: _labels[i],
                  met: dailyGoalsMet[days[i]] ?? false,
                  isToday: days[i] == today,
                  isFuture: days[i].isAfter(today),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final String label;
  final bool met;
  final bool isToday;
  final bool isFuture;

  const _Day({
    required this.label,
    required this.met,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final Widget mark;
    if (met) {
      mark = Container(
        decoration: const BoxDecoration(
          color: AppPalette.forest,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
      );
    } else if (isToday) {
      mark = Container(
        decoration: BoxDecoration(
          color: AppPalette.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.forest, width: 2),
        ),
        child: const Icon(Icons.directions_walk_rounded,
            color: AppPalette.forest, size: 18),
      );
    } else {
      mark = Container(
        decoration: BoxDecoration(
          color: isFuture ? AppPalette.cream : AppPalette.sand,
          shape: BoxShape.circle,
          border: isFuture ? Border.all(color: AppPalette.line) : null,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(width: 36, height: 36, child: mark),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppPalette.forestDeep : AppPalette.muted,
          ),
        ),
      ],
    );
  }
}
