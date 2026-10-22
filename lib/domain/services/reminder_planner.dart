import '../../core/time/local_day.dart';
import '../models/reminder.dart';

enum PlannedKind { reminder, missedFollowUp }

/// One OS-level notification to schedule. It repeats weekly on the weekday and
/// time of [firstFire]; [firstFire] may be pushed a week out to skip today.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.reminderId,
    required this.slotWeekday,
    required this.firstFire,
  });

  /// Stable id: the same reminder/weekday/kind always maps to the same id.
  final int id;
  final PlannedKind kind;
  final int reminderId;

  /// ISO weekday of the reminder slot this belongs to.
  final int slotWeekday;

  /// First fire time, local.
  final DateTime firstFire;

  @override
  String toString() => 'Planned($kind r$reminderId wd$slotWeekday @ $firstFire)';
}

class ReminderPlanInput {
  const ReminderPlanInput({
    required this.now,
    required this.reminders,
    required this.recentDrinkTimes,
    required this.todayTotalMl,
    required this.goalMl,
    required this.missedIntakeAlert,
    required this.remindAfterGoal,
    required this.maxPending,
  });

  final DateTime now;
  final List<Reminder> reminders;

  /// Drink times from roughly the last day and a half (local).
  final List<DateTime> recentDrinkTimes;
  final int todayTotalMl;
  final int goalMl;
  final bool missedIntakeAlert;
  final bool remindAfterGoal;

  /// OS budget for pending notifications (iOS keeps at most 64).
  final int maxPending;
}

class ReminderPlan {
  const ReminderPlan(this.notifications, this.dropped);

  final List<PlannedNotification> notifications;

  /// Notifications that did not fit in the OS budget. They are picked up by the
  /// next sync, which runs on every app open and every logged drink.
  final int dropped;

  /// The next regular reminder that fires today, if any.
  DateTime? nextReminderToday(DateTime now) {
    final today = LocalDay.fromDateTime(now);
    DateTime? best;
    for (final n in notifications) {
      if (n.kind != PlannedKind.reminder) continue;
      if (!n.firstFire.isAfter(now)) continue;
      if (LocalDay.fromDateTime(n.firstFire) != today) continue;
      if (best == null || n.firstFire.isBefore(best)) best = n.firstFire;
    }
    return best;
  }
}

/// Decides exactly which notifications should be pending right now.
///
/// Pure and deterministic: given the same input it returns the same plan, which
/// is what makes the scheduling rules unit-testable. Rules:
/// 1. Each active reminder gets one weekly notification per selected weekday.
/// 2. Today's remaining reminders are skipped once the goal is met, unless
///    "Further reminder" is on.
/// 3. A reminder is skipped if the user drank in the 30 minutes before it.
/// 4. With "Reminder alert" on, a follow-up fires 30 minutes after each reminder,
///    unless a drink was logged around that reminder.
/// 5. If the plan exceeds the OS budget, regular reminders win over follow-ups,
///    and sooner notifications win over later ones.
abstract final class ReminderPlanner {
  static const followUpDelay = Duration(minutes: 30);
  static const recentDrinkWindow = Duration(minutes: 30);

  static ReminderPlan plan(ReminderPlanInput input) {
    final now = input.now;
    final today = LocalDay.fromDateTime(now);
    final goalMet = input.todayTotalMl >= input.goalMl;
    final suppressToday = goalMet && !input.remindAfterGoal;

    bool drankBetween(DateTime from, DateTime to) =>
        input.recentDrinkTimes.any((t) => !t.isBefore(from) && t.isBefore(to));

    final mains = <PlannedNotification>[];
    final followUps = <PlannedNotification>[];

    for (final r in input.reminders) {
      if (!r.isActive) continue;
      for (final wd in r.weekdays.days) {
        // Regular reminder.
        var slot = _nextOccurrence(now, today, wd, r.minuteOfDay);
        if (LocalDay.fromDateTime(slot) == today &&
            (suppressToday || drankBetween(slot.subtract(recentDrinkWindow), slot))) {
          slot = _slotOn(today.addDays(7), r.minuteOfDay);
        }
        mains.add(PlannedNotification(
          id: notificationId(r.id, wd, PlannedKind.reminder),
          kind: PlannedKind.reminder,
          reminderId: r.id,
          slotWeekday: wd,
          firstFire: slot,
        ));

        // Missed-intake follow-up.
        if (input.missedIntakeAlert) {
          var followSlot = _slotWithNextFollowUp(now, today, wd, r.minuteOfDay);
          final followFire = followSlot.add(followUpDelay);
          final skip = (LocalDay.fromDateTime(followSlot) == today && suppressToday) ||
              drankBetween(followSlot.subtract(recentDrinkWindow), followFire);
          if (skip) {
            followSlot = _slotOn(LocalDay.fromDateTime(followSlot).addDays(7), r.minuteOfDay);
          }
          followUps.add(PlannedNotification(
            id: notificationId(r.id, wd, PlannedKind.missedFollowUp),
            kind: PlannedKind.missedFollowUp,
            reminderId: r.id,
            slotWeekday: wd,
            firstFire: followSlot.add(followUpDelay),
          ));
        }
      }
    }

    int bySoonest(PlannedNotification a, PlannedNotification b) => a.firstFire.compareTo(b.firstFire);
    mains.sort(bySoonest);
    followUps.sort(bySoonest);

    final budget = input.maxPending < 0 ? 0 : input.maxPending;
    final kept = <PlannedNotification>[
      ...mains.take(budget),
      ...followUps.take((budget - mains.length).clamp(0, budget)),
    ];
    final dropped = mains.length + followUps.length - kept.length;
    return ReminderPlan(List.unmodifiable(kept), dropped);
  }

  /// Unique, stable id per (reminder, weekday, kind). Fits in a 32-bit int for
  /// reminder ids below ~100 million.
  static int notificationId(int reminderId, int weekday, PlannedKind kind) =>
      reminderId * 20 + (weekday - 1) * 2 + kind.index;

  static DateTime _slotOn(LocalDay day, int minuteOfDay) =>
      DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);

  /// First occurrence of weekday [wd] at [minuteOfDay] strictly after [now].
  static DateTime _nextOccurrence(DateTime now, LocalDay today, int wd, int minuteOfDay) {
    final delta = (wd - today.weekday) % 7;
    final candidate = _slotOn(today.addDays(delta), minuteOfDay);
    return candidate.isAfter(now) ? candidate : _slotOn(today.addDays(delta + 7), minuteOfDay);
  }

  /// The slot whose follow-up (slot + delay) is the first one after [now].
  /// Can be a slot that already passed, e.g. 10:00 when it is 10:10.
  static DateTime _slotWithNextFollowUp(DateTime now, LocalDay today, int wd, int minuteOfDay) {
    final delta = (wd - today.weekday) % 7;
    for (final offset in [delta - 7, delta, delta + 7]) {
      final slot = _slotOn(today.addDays(offset), minuteOfDay);
      if (slot.add(followUpDelay).isAfter(now)) return slot;
    }
    return _slotOn(today.addDays(delta + 14), minuteOfDay);
  }
}
