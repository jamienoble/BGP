/// Utility functions for date handling and formatting
class DateUtils {
  /// Format a DateTime to yyyy-MM-dd string
  /// Example: DateTime(2024, 1, 5) -> '2024-01-05'
  static String todayDateString({DateTime? dateTime}) {
    final date = dateTime ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get the start of a day (midnight)
  static DateTime getDayStart(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Parse a date string in yyyy-MM-dd format
  static DateTime? parseDateString(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Check if the given date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  /// Get the Monday of the current week
  static DateTime getWeekMonday({DateTime? dateTime}) {
    final date = dateTime ?? DateTime.now();
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Get all days of the current week starting from Monday
  static List<DateTime> getCurrentWeekDays({DateTime? dateTime}) {
    final monday = getWeekMonday(dateTime: dateTime);
    return List.generate(
      7,
      (index) => DateTime(monday.year, monday.month, monday.day + index),
    );
  }
}
