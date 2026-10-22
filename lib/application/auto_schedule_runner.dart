import '../core/time/local_day.dart';
import '../data/repositories/intake_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/models/user_settings.dart';
import '../domain/services/auto_schedule.dart';

/// Keeps the reminder list in step with Auto mode.
class AutoScheduleRunner {
  AutoScheduleRunner({
    required IntakeRepository intake,
    required ReminderRepository reminders,
    required SettingsRepository settings,
    DateTime Function()? now,
  })  : _intake = intake,
        _reminders = reminders,
        _settings = settings,
        _now = now ?? DateTime.now;

  final IntakeRepository _intake;
  final ReminderRepository _reminders;
  final SettingsRepository _settings;
  final DateTime Function() _now;

  /// Rebuilds the schedule when in Auto mode. Without [force] it runs at most
  /// once per day. Returns true when the reminder list changed.
  Future<bool> run({bool force = false}) async {
    final settings = _settings.load();
    if (settings.reminderMode != ReminderMode.auto) return false;

    final now = _now();
    final today = LocalDay.fromDateTime(now);
    if (!force && _settings.lastAutoScheduleDay == today.key) return false;

    final history = await _intake.between(today.addDays(-14).start, today.start);
    final minutes = AutoSchedule.generate(
      goalMl: settings.goalMl,
      cupMl: settings.cupMl,
      history: history.map((e) => e.loggedAt).toList(growable: false),
    );
    await _reminders.replaceAll(minutes);
    await _settings.setLastAutoScheduleDay(today.key);
    return true;
  }
}
