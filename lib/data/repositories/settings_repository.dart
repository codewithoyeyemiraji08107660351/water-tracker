import 'package:shared_preferences/shared_preferences.dart';

import '../../core/units/volume.dart';
import '../../domain/models/user_settings.dart';

/// Persists [UserSettings] in SharedPreferences. Unknown or corrupt values fall
/// back to defaults instead of crashing the app.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kGoal = 'settings.goal_ml';
  static const _kCup = 'settings.cup_ml';
  static const _kUnit = 'settings.unit';
  static const _kGender = 'settings.gender';
  static const _kWeight = 'settings.weight_kg';
  static const _kMode = 'settings.reminder_mode';
  static const _kSound = 'settings.reminder_sound';
  static const _kMissed = 'settings.missed_alert';
  static const _kAfterGoal = 'settings.remind_after_goal';
  static const _kAutoDay = 'meta.auto_schedule_day';
  static const _kPermissionAsked = 'meta.notification_permission_asked';

  UserSettings load() {
    const d = UserSettings.defaults;
    return UserSettings(
      goalMl: (_prefs.getInt(_kGoal) ?? d.goalMl).clamp(UserSettings.minGoalMl, UserSettings.maxGoalMl),
      cupMl: (_prefs.getInt(_kCup) ?? d.cupMl).clamp(10, 5000),
      unit: _enumByName(UnitSystem.values, _prefs.getString(_kUnit)) ?? d.unit,
      gender: _enumByName(Gender.values, _prefs.getString(_kGender)),
      weightKg: _prefs.getDouble(_kWeight),
      reminderMode: _enumByName(ReminderMode.values, _prefs.getString(_kMode)) ?? d.reminderMode,
      reminderSound: _enumByName(ReminderSound.values, _prefs.getString(_kSound)) ?? d.reminderSound,
      missedIntakeAlert: _prefs.getBool(_kMissed) ?? d.missedIntakeAlert,
      remindAfterGoal: _prefs.getBool(_kAfterGoal) ?? d.remindAfterGoal,
    );
  }

  Future<void> save(UserSettings s) async {
    await Future.wait([
      _prefs.setInt(_kGoal, s.goalMl),
      _prefs.setInt(_kCup, s.cupMl),
      _prefs.setString(_kUnit, s.unit.name),
      if (s.gender != null) _prefs.setString(_kGender, s.gender!.name),
      if (s.weightKg != null) _prefs.setDouble(_kWeight, s.weightKg!),
      _prefs.setString(_kMode, s.reminderMode.name),
      _prefs.setString(_kSound, s.reminderSound.name),
      _prefs.setBool(_kMissed, s.missedIntakeAlert),
      _prefs.setBool(_kAfterGoal, s.remindAfterGoal),
    ]);
  }

  /// Day key of the last time Auto mode rebuilt the schedule.
  String? get lastAutoScheduleDay => _prefs.getString(_kAutoDay);
  Future<void> setLastAutoScheduleDay(String dayKey) => _prefs.setString(_kAutoDay, dayKey);

  bool get notificationPermissionAsked => _prefs.getBool(_kPermissionAsked) ?? false;
  Future<void> setNotificationPermissionAsked() => _prefs.setBool(_kPermissionAsked, true);

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
