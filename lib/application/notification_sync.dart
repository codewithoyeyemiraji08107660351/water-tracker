import 'package:flutter/foundation.dart';

import '../core/time/local_day.dart';
import '../data/repositories/intake_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/services/reminder_planner.dart';
import '../infrastructure/notifications/notification_service.dart';

/// Rebuilds the OS notification queue from the current data.
///
/// Called after anything that can change what should fire: a logged or edited
/// drink, a reminder change, a settings change, app resume and a new day.
/// Calls are coalesced so a burst of changes triggers at most one extra run.
class NotificationSync {
  NotificationSync({
    required IntakeRepository intake,
    required ReminderRepository reminders,
    required SettingsRepository settings,
    required NotificationService service,
    required void Function(ReminderPlan plan) onPlanned,
    DateTime Function()? now,
  })  : _intake = intake,
        _reminders = reminders,
        _settings = settings,
        _service = service,
        _onPlanned = onPlanned,
        _now = now ?? DateTime.now;

  final IntakeRepository _intake;
  final ReminderRepository _reminders;
  final SettingsRepository _settings;
  final NotificationService _service;
  final void Function(ReminderPlan plan) _onPlanned;
  final DateTime Function() _now;

  Future<void>? _running;
  bool _rerun = false;

  Future<void> sync() {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    final future = _loop();
    _running = future;
    return future;
  }

  Future<void> _loop() async {
    try {
      do {
        _rerun = false;
        await _syncOnce();
      } while (_rerun);
    } catch (e, st) {
      // Never let a scheduling failure break logging a drink; log for debugging.
      debugPrint('Notification sync failed: $e\n$st');
    } finally {
      _running = null;
    }
  }

  Future<void> _syncOnce() async {
    final now = _now();
    final settings = _settings.load();
    final today = LocalDay.fromDateTime(now);
    final reminders = await _reminders.all();
    final recent = await _intake.between(now.subtract(const Duration(hours: 36)), now.add(const Duration(minutes: 1)));
    final todayTotal = recent
        .where((e) => LocalDay.fromDateTime(e.loggedAt) == today)
        .fold<int>(0, (sum, e) => sum + e.amountMl);

    final plan = ReminderPlanner.plan(ReminderPlanInput(
      now: now,
      reminders: reminders,
      recentDrinkTimes: recent.map((e) => e.loggedAt).toList(growable: false),
      todayTotalMl: todayTotal,
      goalMl: settings.goalMl,
      missedIntakeAlert: settings.missedIntakeAlert,
      remindAfterGoal: settings.remindAfterGoal,
      maxPending: NotificationService.maxPending,
    ));

    await _service.apply(plan, settings.reminderSound);
    if (plan.dropped > 0) {
      debugPrint('Notification budget reached, ${plan.dropped} deferred to next sync.');
    }
    _onPlanned(plan);
  }
}
