import 'dart:math' as math;

/// Builds the reminder list for Auto mode.
///
/// "We optimize reminder time based on your record history": once there is
/// enough history, reminders are spread across the hours the user actually
/// drinks (10th to 90th percentile of drink times over the last two weeks).
/// Before that, a sensible 08:00 to 21:00 window is used.
abstract final class AutoSchedule {
  static const int defaultStartMinute = 8 * 60;
  static const int defaultEndMinute = 21 * 60;
  static const int earliestMinute = 6 * 60;
  static const int latestMinute = 23 * 60;
  static const int minWindowMinutes = 6 * 60;
  static const int minCount = 4;
  static const int maxCount = 8;
  static const int minEntriesForLearning = 10;
  static const int minDaysForLearning = 3;
  static const int roundTo = 15;

  /// [history] is the list of drink times from the last 14 days (local).
  static List<int> generate({
    required int goalMl,
    required int cupMl,
    required List<DateTime> history,
  }) {
    final (start, end) = activeWindow(history);
    final count = (goalMl / math.max(cupMl, 1)).ceil().clamp(minCount, maxCount);

    final times = <int>{};
    final step = (end - start) / (count - 1);
    for (var i = 0; i < count; i++) {
      times.add(_round(start + step * i));
    }
    return times.toList()..sort();
  }

  /// Returns (startMinute, endMinute) of the user's drinking window.
  static (int, int) activeWindow(List<DateTime> history) {
    final distinctDays = history.map((t) => DateTime(t.year, t.month, t.day)).toSet().length;
    if (history.length < minEntriesForLearning || distinctDays < minDaysForLearning) {
      return (defaultStartMinute, defaultEndMinute);
    }

    final minutes = history.map((t) => t.hour * 60 + t.minute).toList()..sort();
    var start = _round(_percentile(minutes, 0.10)).clamp(earliestMinute, latestMinute);
    var end = _round(_percentile(minutes, 0.90)).clamp(earliestMinute, latestMinute);

    if (end - start < minWindowMinutes) {
      final mid = (start + end) ~/ 2;
      start = mid - minWindowMinutes ~/ 2;
      end = mid + minWindowMinutes ~/ 2;
      if (start < earliestMinute) {
        end += earliestMinute - start;
        start = earliestMinute;
      }
      if (end > latestMinute) {
        start -= end - latestMinute;
        end = latestMinute;
      }
    }
    return (start, end);
  }

  static double _percentile(List<int> sorted, double p) {
    final index = (sorted.length - 1) * p;
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower].toDouble();
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
  }

  static int _round(num minute) => ((minute / roundTo).round() * roundTo).clamp(0, 1439);
}
