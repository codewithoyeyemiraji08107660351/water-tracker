import 'package:flutter_test/flutter_test.dart';
import 'package:water_tracker/domain/models/reminder.dart';
import 'package:water_tracker/domain/services/reminder_planner.dart';

// 20 Oct 2026 is a Tuesday (ISO weekday 2).
DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 10, day, hour, minute);

Reminder reminder(int id, int hour, [int minute = 0, Weekdays days = Weekdays.everyday, bool enabled = true]) =>
    Reminder(id: id, minuteOfDay: hour * 60 + minute, weekdays: days, enabled: enabled);

ReminderPlan plan({
  required DateTime now,
  required List<Reminder> reminders,
  List<DateTime> drinks = const [],
  int total = 0,
  int goal = 2000,
  bool followUps = false,
  bool afterGoal = false,
  int max = 400,
}) =>
    ReminderPlanner.plan(ReminderPlanInput(
      now: now,
      reminders: reminders,
      recentDrinkTimes: drinks,
      todayTotalMl: total,
      goalMl: goal,
      missedIntakeAlert: followUps,
      remindAfterGoal: afterGoal,
      maxPending: max,
    ));

PlannedNotification find(ReminderPlan p, int weekday, PlannedKind kind, {int reminderId = 1}) =>
    p.notifications.firstWhere((n) => n.slotWeekday == weekday && n.kind == kind && n.reminderId == reminderId);

void main() {
  group('regular reminders', () {
    test('one weekly notification per selected weekday, all in the future', () {
      final p = plan(now: at(20, 10, 10), reminders: [reminder(1, 9)]);
      expect(p.notifications, hasLength(7));
      expect(p.dropped, 0);
      for (final n in p.notifications) {
        expect(n.firstFire.isAfter(at(20, 10, 10)), isTrue);
      }
      // Today's 09:00 already passed, so Tuesday starts next week.
      expect(find(p, DateTime.tuesday, PlannedKind.reminder).firstFire, at(27, 9));
      expect(find(p, DateTime.wednesday, PlannedKind.reminder).firstFire, at(21, 9));
    });

    test('only the selected weekdays are scheduled', () {
      final weekdaysOnly = const Weekdays(31); // Mon to Fri
      final p = plan(now: at(20, 8), reminders: [reminder(1, 9, 0, weekdaysOnly)]);
      expect(p.notifications.map((n) => n.slotWeekday).toSet(), {1, 2, 3, 4, 5});
    });

    test('disabled reminders and reminders with no days produce nothing', () {
      final p = plan(now: at(20, 8), reminders: [
        reminder(1, 9, 0, Weekdays.everyday, false),
        reminder(2, 10, 0, Weekdays.none),
      ]);
      expect(p.notifications, isEmpty);
    });

    test('goal met skips the rest of today unless Further reminder is on', () {
      final skipped = plan(now: at(20, 10), reminders: [reminder(1, 11)], total: 2000);
      expect(find(skipped, DateTime.tuesday, PlannedKind.reminder).firstFire, at(27, 11));
      expect(find(skipped, DateTime.wednesday, PlannedKind.reminder).firstFire, at(21, 11));

      final kept = plan(now: at(20, 10), reminders: [reminder(1, 11)], total: 2000, afterGoal: true);
      expect(find(kept, DateTime.tuesday, PlannedKind.reminder).firstFire, at(20, 11));
    });

    test('a drink in the 30 minutes before a reminder skips it today', () {
      final p = plan(now: at(20, 10, 45), reminders: [reminder(1, 11)], drinks: [at(20, 10, 40)]);
      expect(find(p, DateTime.tuesday, PlannedKind.reminder).firstFire, at(27, 11));
    });

    test('an older drink does not skip the reminder', () {
      final p = plan(now: at(20, 10, 45), reminders: [reminder(1, 11)], drinks: [at(20, 10, 0)]);
      expect(find(p, DateTime.tuesday, PlannedKind.reminder).firstFire, at(20, 11));
    });
  });

  group('missed-intake follow-ups', () {
    test('fires 30 minutes after a reminder when nothing was logged', () {
      final p = plan(now: at(20, 10, 10), reminders: [reminder(1, 10)], followUps: true);
      expect(find(p, DateTime.tuesday, PlannedKind.missedFollowUp).firstFire, at(20, 10, 30));
    });

    test('a drink after the reminder cancels today\'s follow-up', () {
      final p = plan(
        now: at(20, 10, 10),
        reminders: [reminder(1, 10)],
        drinks: [at(20, 10, 5)],
        followUps: true,
      );
      expect(find(p, DateTime.tuesday, PlannedKind.missedFollowUp).firstFire, at(27, 10, 30));
    });

    test('a drink just before the reminder skips both reminder and follow-up', () {
      final p = plan(
        now: at(20, 9, 50),
        reminders: [reminder(1, 10)],
        drinks: [at(20, 9, 45)],
        followUps: true,
      );
      expect(find(p, DateTime.tuesday, PlannedKind.reminder).firstFire, at(27, 10));
      expect(find(p, DateTime.tuesday, PlannedKind.missedFollowUp).firstFire, at(27, 10, 30));
    });

    test('goal met suppresses today\'s follow-up', () {
      final p = plan(now: at(20, 10, 10), reminders: [reminder(1, 10)], total: 2500, followUps: true);
      expect(find(p, DateTime.tuesday, PlannedKind.missedFollowUp).firstFire, at(27, 10, 30));
    });

    test('no follow-ups when the alert is off', () {
      final p = plan(now: at(20, 10, 10), reminders: [reminder(1, 10)]);
      expect(p.notifications.where((n) => n.kind == PlannedKind.missedFollowUp), isEmpty);
    });
  });

  group('budget and ids', () {
    test('respects the OS budget, keeping regular reminders first and soonest first', () {
      final reminders = [for (var i = 0; i < 9; i++) reminder(i + 1, 8 + i)];
      final p = plan(now: at(20, 7), reminders: reminders, followUps: true, max: 60);
      expect(p.notifications, hasLength(60));
      expect(p.notifications.every((n) => n.kind == PlannedKind.reminder), isTrue);
      expect(p.dropped, 63 + 63 - 60);
      final kept = p.notifications.map((n) => n.firstFire).toList();
      final sorted = [...kept]..sort();
      expect(kept, sorted);
    });

    test('notification ids are unique and stable', () {
      final reminders = [reminder(1, 8), reminder(2, 9), reminder(3, 10)];
      final a = plan(now: at(20, 7), reminders: reminders, followUps: true);
      final b = plan(now: at(21, 7), reminders: reminders, followUps: true);
      final idsA = a.notifications.map((n) => n.id).toSet();
      expect(idsA, hasLength(a.notifications.length));
      expect(idsA, b.notifications.map((n) => n.id).toSet());
    });
  });

  test('nextReminderToday returns the soonest upcoming reminder today', () {
    final p = plan(now: at(20, 10, 10), reminders: [reminder(1, 9), reminder(2, 11), reminder(3, 15)]);
    expect(p.nextReminderToday(at(20, 10, 10)), at(20, 11));
    expect(p.nextReminderToday(at(20, 16)), isNull);
  });
}
