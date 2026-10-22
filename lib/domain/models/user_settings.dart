import '../../core/units/volume.dart';

enum Gender {
  female('Female'),
  male('Male'),
  other('Prefer not to say');

  const Gender(this.label);
  final String label;
}

/// How the reminder list is produced.
enum ReminderMode {
  /// Times are spread across the hours the user actually drinks, learned from history.
  auto('Auto'),

  /// The user manages the list on the Reminder schedule screen.
  manual('Manual');

  const ReminderMode(this.label);
  final String label;
}

/// Notification sound. Android locks a channel's sound once created, so each
/// option maps to its own channel (see NotificationService).
enum ReminderSound {
  systemDefault('System default'),
  silent('Silent (vibrate only)');

  const ReminderSound(this.label);
  final String label;
}

/// Everything on the Settings screen. Immutable; update with [copyWith].
class UserSettings {
  const UserSettings({
    required this.goalMl,
    required this.cupMl,
    required this.unit,
    required this.gender,
    required this.weightKg,
    required this.reminderMode,
    required this.reminderSound,
    required this.missedIntakeAlert,
    required this.remindAfterGoal,
  });

  static const defaults = UserSettings(
    goalMl: 2000,
    cupMl: 200,
    unit: UnitSystem.metric,
    gender: null,
    weightKg: null,
    reminderMode: ReminderMode.auto,
    reminderSound: ReminderSound.systemDefault,
    missedIntakeAlert: true,
    remindAfterGoal: false,
  );

  static const int minGoalMl = 500;
  static const int maxGoalMl = 6000;

  final int goalMl;

  /// Cup size used by the quick-add button on Home.
  final int cupMl;
  final UnitSystem unit;
  final Gender? gender;
  final double? weightKg;
  final ReminderMode reminderMode;
  final ReminderSound reminderSound;

  /// "Reminder alert": nudge again if nothing was logged after a reminder.
  final bool missedIntakeAlert;

  /// "Further reminder": keep reminding after today's goal is reached.
  final bool remindAfterGoal;

  UserSettings copyWith({
    int? goalMl,
    int? cupMl,
    UnitSystem? unit,
    Gender? gender,
    double? weightKg,
    ReminderMode? reminderMode,
    ReminderSound? reminderSound,
    bool? missedIntakeAlert,
    bool? remindAfterGoal,
  }) =>
      UserSettings(
        goalMl: goalMl ?? this.goalMl,
        cupMl: cupMl ?? this.cupMl,
        unit: unit ?? this.unit,
        gender: gender ?? this.gender,
        weightKg: weightKg ?? this.weightKg,
        reminderMode: reminderMode ?? this.reminderMode,
        reminderSound: reminderSound ?? this.reminderSound,
        missedIntakeAlert: missedIntakeAlert ?? this.missedIntakeAlert,
        remindAfterGoal: remindAfterGoal ?? this.remindAfterGoal,
      );
}
