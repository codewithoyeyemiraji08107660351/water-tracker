import 'dart:math' as math;

import '../../core/time/local_day.dart';
import '../models/intake_entry.dart';

/// Totals for one local day.
class DayTotal {
  const DayTotal({required this.day, required this.totalMl, required this.drinks, required this.goalMl});

  final LocalDay day;
  final int totalMl;
  final int drinks;
  final int goalMl;

  /// 0.0 to 1.0, capped at 1 so one big day cannot inflate an average.
  double get completion => goalMl <= 0 ? 0 : math.min(totalMl / goalMl, 1.0);
  bool get goalMet => totalMl >= goalMl;
}

/// Pure functions behind the History screen. Kept free of Flutter and SQLite so
/// they can be unit tested directly.
abstract final class StatsCalculator {
  /// Builds one [DayTotal] per day from [from] to [to] inclusive. Days with no
  /// drinks are included with 0 ml, because a missed day is real data.
  static List<DayTotal> buildDays({
    required LocalDay from,
    required LocalDay to,
    required List<IntakeEntry> entries,
    required Map<String, int> goalsByDay,
    required int fallbackGoalMl,
  }) {
    if (to.isBefore(from)) return const [];
    final totals = <LocalDay, int>{};
    final counts = <LocalDay, int>{};
    for (final e in entries) {
      final d = LocalDay.fromDateTime(e.loggedAt);
      totals[d] = (totals[d] ?? 0) + e.amountMl;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final days = <DayTotal>[];
    for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
      days.add(DayTotal(
        day: d,
        totalMl: totals[d] ?? 0,
        drinks: counts[d] ?? 0,
        goalMl: goalsByDay[d.key] ?? fallbackGoalMl,
      ));
    }
    return days;
  }

  /// Restricts [days] to the window the user has actually been tracking:
  /// on or after their first drink and not in the future.
  static List<DayTotal> tracked(List<DayTotal> days, {required LocalDay? firstDay, required LocalDay today}) {
    if (firstDay == null) return const [];
    return days.where((d) => !d.day.isBefore(firstDay) && !d.day.isAfter(today)).toList(growable: false);
  }

  static double? averageMl(List<DayTotal> days) =>
      days.isEmpty ? null : days.fold<int>(0, (s, d) => s + d.totalMl) / days.length;

  static double? averageDrinks(List<DayTotal> days) =>
      days.isEmpty ? null : days.fold<int>(0, (s, d) => s + d.drinks) / days.length;

  /// Average completion as a percentage (0 to 100).
  static double? averageCompletionPct(List<DayTotal> days) =>
      days.isEmpty ? null : days.fold<double>(0, (s, d) => s + d.completion) / days.length * 100;

  /// Twelve values (Jan..Dec), null for months with no tracked days.
  static List<double?> monthlyCompletionPct(List<DayTotal> trackedDays, int year) {
    final sums = List<double>.filled(12, 0);
    final counts = List<int>.filled(12, 0);
    for (final d in trackedDays) {
      if (d.day.year != year) continue;
      sums[d.day.month - 1] += d.completion;
      counts[d.day.month - 1]++;
    }
    return [for (var m = 0; m < 12; m++) counts[m] == 0 ? null : sums[m] / counts[m] * 100];
  }

  /// One value per day of the month, null for untracked days.
  static List<double?> dailyCompletionPct(List<DayTotal> trackedDays, int year, int month) {
    final length = LocalDay.daysInMonth(year, month);
    final values = List<double?>.filled(length, null);
    for (final d in trackedDays) {
      if (d.day.year == year && d.day.month == month) {
        values[d.day.day - 1] = d.completion * 100;
      }
    }
    return values;
  }
}
