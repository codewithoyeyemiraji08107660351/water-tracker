import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/local_day.dart';
import '../domain/services/stats_calculator.dart';
import 'providers.dart';
import 'settings_controller.dart';

enum HistoryPeriod { month, year }

/// Which slice of history the screen is showing.
class HistoryQuery {
  const HistoryQuery({required this.period, required this.year, required this.month});

  final HistoryPeriod period;
  final int year;
  final int month;

  HistoryQuery shift(int delta) {
    if (period == HistoryPeriod.year) {
      return HistoryQuery(period: period, year: year + delta, month: month);
    }
    final d = DateTime(year, month + delta);
    return HistoryQuery(period: period, year: d.year, month: d.month);
  }

  HistoryQuery withPeriod(HistoryPeriod p) => HistoryQuery(period: p, year: year, month: month);

  LocalDay get start => period == HistoryPeriod.year ? LocalDay(year, 1, 1) : LocalDay(year, month, 1);

  LocalDay get end => period == HistoryPeriod.year
      ? LocalDay(year, 12, 31)
      : LocalDay(year, month, LocalDay.daysInMonth(year, month));

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery && other.period == period && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(period, year, month);
}

class HistoryData {
  const HistoryData({
    required this.bars,
    required this.week,
    required this.weeklyAverageMl,
    required this.monthlyAverageMl,
    required this.periodCompletionPct,
    required this.drinksPerDay,
    required this.hasAnyData,
  });

  /// Completion % per bar (12 months or N days). Null = no data for that bar.
  final List<double?> bars;

  /// Current week, Sunday to Saturday. Null entries are days in the future.
  final List<DayTotal?> week;

  final double? weeklyAverageMl;
  final double? monthlyAverageMl;
  final double? periodCompletionPct;
  final double? drinksPerDay;
  final bool hasAnyData;
}

final historyProvider = FutureProvider.autoDispose.family<HistoryData, HistoryQuery>((ref, query) async {
  ref.watch(intakeRevisionProvider);
  final today = ref.watch(currentDayProvider);
  final fallbackGoal = ref.watch(settingsControllerProvider.select((s) => s.goalMl));
  final intake = ref.read(intakeRepositoryProvider);
  final goals = ref.read(goalRepositoryProvider);

  final weekStart = today.startOfWeekSunday;
  final last30Start = today.addDays(-29);

  // One fetch covers the period, the trailing 30 days and the current week.
  final from = [query.start, last30Start, weekStart].reduce((a, b) => a.isBefore(b) ? a : b);
  final to = [query.end, today, weekStart.addDays(6)].reduce((a, b) => a.isAfter(b) ? a : b);

  final (entries, goalMap, firstDay) = await (
    intake.between(from.start, to.end),
    goals.goalsBetween(from, to),
    intake.firstDay(),
  ).wait;

  final allDays = StatsCalculator.buildDays(
    from: from,
    to: to,
    entries: entries,
    goalsByDay: goalMap,
    fallbackGoalMl: fallbackGoal,
  );
  final tracked = StatsCalculator.tracked(allDays, firstDay: firstDay, today: today);

  List<DayTotal> inRange(LocalDay a, LocalDay b) =>
      tracked.where((d) => !d.day.isBefore(a) && !d.day.isAfter(b)).toList(growable: false);

  final periodDays = inRange(query.start, query.end);
  final last7 = inRange(today.addDays(-6), today);
  final last30 = inRange(last30Start, today);

  final byDay = {for (final d in allDays) d.day: d};
  final week = [
    for (var i = 0; i < 7; i++)
      weekStart.addDays(i).isAfter(today) ? null : byDay[weekStart.addDays(i)],
  ];

  return HistoryData(
    bars: query.period == HistoryPeriod.year
        ? StatsCalculator.monthlyCompletionPct(tracked, query.year)
        : StatsCalculator.dailyCompletionPct(tracked, query.year, query.month),
    week: week,
    weeklyAverageMl: StatsCalculator.averageMl(last7),
    monthlyAverageMl: StatsCalculator.averageMl(last30),
    periodCompletionPct: StatsCalculator.averageCompletionPct(periodDays),
    drinksPerDay: StatsCalculator.averageDrinks(last7),
    hasAnyData: firstDay != null,
  );
});
