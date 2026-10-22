import 'package:flutter_test/flutter_test.dart';
import 'package:water_tracker/core/time/local_day.dart';
import 'package:water_tracker/core/units/volume.dart';
import 'package:water_tracker/domain/models/intake_entry.dart';
import 'package:water_tracker/domain/models/reminder.dart';
import 'package:water_tracker/domain/models/user_settings.dart';
import 'package:water_tracker/domain/services/auto_schedule.dart';
import 'package:water_tracker/domain/services/hydration_goal.dart';
import 'package:water_tracker/domain/services/stats_calculator.dart';

IntakeEntry entry(int id, DateTime at, int ml) => IntakeEntry(id: id, amountMl: ml, loggedAt: at);

void main() {
  group('LocalDay', () {
    test('week starts on Sunday', () {
      expect(LocalDay(2026, 10, 20).startOfWeekSunday, LocalDay(2026, 10, 18));
      expect(LocalDay(2026, 10, 18).startOfWeekSunday, LocalDay(2026, 10, 18));
    });

    test('key round-trips', () {
      final d = LocalDay(2026, 3, 7);
      expect(d.key, '2026-03-07');
      expect(LocalDay.parse(d.key), d);
    });

    test('addDays crosses month and year boundaries', () {
      expect(LocalDay(2026, 12, 31).addDays(1), LocalDay(2027, 1, 1));
    });
  });

  group('StatsCalculator', () {
    final days = StatsCalculator.buildDays(
      from: LocalDay(2026, 10, 18),
      to: LocalDay(2026, 10, 20),
      entries: [
        entry(1, DateTime(2026, 10, 18, 9), 1000),
        entry(2, DateTime(2026, 10, 18, 15), 1500),
        entry(3, DateTime(2026, 10, 20, 9), 500),
      ],
      goalsByDay: {'2026-10-20': 1000},
      fallbackGoalMl: 2000,
    );

    test('includes empty days and uses the per-day goal snapshot', () {
      expect(days, hasLength(3));
      expect(days[0].totalMl, 2500);
      expect(days[0].drinks, 2);
      expect(days[1].totalMl, 0);
      expect(days[2].goalMl, 1000);
    });

    test('completion is capped at 100%', () {
      expect(days[0].completion, 1.0);
      expect(days[2].completion, 0.5);
      expect(StatsCalculator.averageCompletionPct(days), closeTo(50, 0.001));
    });

    test('tracked drops days before the first drink and in the future', () {
      final tracked = StatsCalculator.tracked(days, firstDay: LocalDay(2026, 10, 19), today: LocalDay(2026, 10, 19));
      expect(tracked.map((d) => d.day), [LocalDay(2026, 10, 19)]);
      expect(StatsCalculator.tracked(days, firstDay: null, today: LocalDay(2026, 10, 20)), isEmpty);
    });

    test('monthly completion leaves untracked months empty', () {
      final monthly = StatsCalculator.monthlyCompletionPct(days, 2026);
      expect(monthly, hasLength(12));
      expect(monthly[8], isNull);
      expect(monthly[9], closeTo(50, 0.001));
    });

    test('averages are null with no data', () {
      expect(StatsCalculator.averageMl(const []), isNull);
      expect(StatsCalculator.averageDrinks(const []), isNull);
    });
  });

  group('AutoSchedule', () {
    test('uses 08:00 to 21:00 without enough history', () {
      final times = AutoSchedule.generate(goalMl: 2000, cupMl: 200, history: const []);
      expect(times.first, 8 * 60);
      expect(times.last, 21 * 60);
      expect(times, hasLength(AutoSchedule.maxCount));
      expect(times.every((m) => m % 15 == 0), isTrue);
      expect(times, [...times]..sort());
    });

    test('never fewer than the minimum count', () {
      final times = AutoSchedule.generate(goalMl: 600, cupMl: 500, history: const []);
      expect(times, hasLength(AutoSchedule.minCount));
    });

    test('learns the drinking window from history', () {
      final history = [
        for (var d = 1; d <= 4; d++) ...[
          DateTime(2026, 10, d, 10, 0),
          DateTime(2026, 10, d, 14, 0),
          DateTime(2026, 10, d, 18, 0),
        ],
      ];
      final (start, end) = AutoSchedule.activeWindow(history);
      expect(start, 10 * 60);
      expect(end, 18 * 60);
    });

    test('a narrow window is widened to at least six hours', () {
      final history = [for (var d = 1; d <= 5; d++) ...[DateTime(2026, 10, d, 12), DateTime(2026, 10, d, 13)]];
      final (start, end) = AutoSchedule.activeWindow(history);
      expect(end - start, greaterThanOrEqualTo(AutoSchedule.minWindowMinutes));
    });
  });

  group('HydrationGoal', () {
    test('weight based, rounded to 50 ml', () {
      expect(HydrationGoal.suggestMl(weightKg: 70), 2300);
    });

    test('falls back to gender defaults and clamps', () {
      expect(HydrationGoal.suggestMl(gender: Gender.female), 1600);
      expect(HydrationGoal.suggestMl(), 1800);
      expect(HydrationGoal.suggestMl(weightKg: 20), HydrationGoal.minSuggested);
    });
  });

  group('Weekdays and Volume', () {
    test('weekday mask toggles and describes', () {
      expect(Weekdays.everyday.describe(), 'Everyday');
      expect(const Weekdays(31).describe(), 'Weekdays');
      final w = Weekdays.none.toggle(DateTime.monday).toggle(DateTime.friday);
      expect(w.days, [1, 5]);
      expect(w.describe(), 'Mon, Fri');
    });

    test('imperial conversion round-trips within 1 ml', () {
      final shown = Volume.fromMl(250, UnitSystem.imperial);
      expect((Volume.toMl(shown, UnitSystem.imperial) - 250).abs(), lessThanOrEqualTo(1));
      expect(Volume.format(200, UnitSystem.metric), '200 ml');
      expect(Volume.format(200, UnitSystem.imperial), '6.8 fl oz');
    });
  });
}
