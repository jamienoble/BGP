import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/utils/date_utils.dart' as date_utils;

/// Goal changes take effect from the next day. The goal that was in force
/// when the day's first change was made stays pinned until midnight, so
/// lowering the goal cannot unlock apps early and raising it cannot
/// re-lock apps that were already earned.
class GoalRules {
  /// The goal that applies today, given the saved goal.
  static Future<int> effectiveGoal(int? savedGoal) async {
    final goal = savedGoal ?? AppConstants.defaultDailyStepGoal;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(AppConstants.prefGoalFloorDate) !=
        date_utils.DateUtils.todayDateString()) {
      return goal;
    }
    return prefs.getInt(AppConstants.prefGoalFloorValue) ?? goal;
  }

  /// Pin [previousGoal] for the rest of today. Later changes on the same day
  /// keep the original pin.
  static Future<void> pinForToday(int previousGoal) async {
    final prefs = await SharedPreferences.getInstance();
    final today = date_utils.DateUtils.todayDateString();
    if (prefs.getString(AppConstants.prefGoalFloorDate) == today) return;
    await prefs.setString(AppConstants.prefGoalFloorDate, today);
    await prefs.setInt(AppConstants.prefGoalFloorValue, previousGoal);
  }
}
