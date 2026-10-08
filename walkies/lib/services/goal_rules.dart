import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

/// A lowered goal only takes effect from the next day, so it cannot be used
/// to unlock apps immediately. The previous goal is held as a floor for the
/// rest of the day it was lowered on.
class GoalRules {
  /// The goal that applies today, given the saved goal.
  static Future<int> effectiveGoal(int? savedGoal) async {
    final goal = savedGoal ?? AppConstants.defaultDailyStepGoal;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(AppConstants.prefGoalFloorDate) !=
        date_utils.DateUtils.todayDateString()) {
      return goal;
    }
    return max(goal, prefs.getInt(AppConstants.prefGoalFloorValue) ?? 0);
  }

  /// Keep [previousGoal] in force for the rest of today.
  static Future<void> holdForToday(int previousGoal) async {
    final prefs = await SharedPreferences.getInstance();
    final today = date_utils.DateUtils.todayDateString();
    final existing = prefs.getString(AppConstants.prefGoalFloorDate) == today
        ? prefs.getInt(AppConstants.prefGoalFloorValue) ?? 0
        : 0;
    await prefs.setString(AppConstants.prefGoalFloorDate, today);
    await prefs.setInt(
      AppConstants.prefGoalFloorValue,
      max(existing, previousGoal),
    );
  }
}
