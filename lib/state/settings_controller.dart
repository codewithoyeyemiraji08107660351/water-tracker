import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/user_settings.dart';
import 'providers.dart';
import 'reminders_controller.dart';

class SettingsController extends Notifier<UserSettings> {
  @override
  UserSettings build() => ref.watch(settingsRepositoryProvider).load();

  /// Applies [change], persists it, and runs the side effects the change needs:
  /// goal snapshot, Auto schedule rebuild, notification resync.
  Future<void> update(UserSettings Function(UserSettings current) change) async {
    final before = state;
    final after = change(before);
    state = after;
    await ref.read(settingsRepositoryProvider).save(after);

    if (after.goalMl != before.goalMl) {
      await ref.read(goalRepositoryProvider).setGoalForDay(ref.read(currentDayProvider), after.goalMl);
      ref.read(intakeRevisionProvider.notifier).bump();
    }

    final autoInputsChanged = after.reminderMode == ReminderMode.auto &&
        (before.reminderMode != ReminderMode.auto ||
            after.goalMl != before.goalMl ||
            after.cupMl != before.cupMl);
    if (autoInputsChanged) {
      await ref.read(autoScheduleRunnerProvider).run(force: true);
      ref.invalidate(remindersControllerProvider);
    }

    await ref.read(notificationSyncProvider).sync();
  }

  /// Used when the user edits the schedule by hand: switch to Manual without
  /// triggering an Auto rebuild.
  Future<void> switchToManualIfAuto() async {
    if (state.reminderMode != ReminderMode.auto) return;
    state = state.copyWith(reminderMode: ReminderMode.manual);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

final settingsControllerProvider = NotifierProvider<SettingsController, UserSettings>(SettingsController.new);
