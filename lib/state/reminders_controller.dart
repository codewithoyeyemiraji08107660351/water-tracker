import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/reminder.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// The reminder list on the Reminder schedule screen.
///
/// Any manual edit switches Auto mode to Manual, so the app never silently
/// overwrites a schedule the user shaped by hand.
class RemindersController extends AsyncNotifier<List<Reminder>> {
  static const int maxReminders = 12;

  @override
  Future<List<Reminder>> build() => ref.watch(reminderRepositoryProvider).all();

  Future<void> add(int minuteOfDay) async {
    final current = state.value ?? const <Reminder>[];
    if (current.length >= maxReminders) {
      throw StateError('You can have up to $maxReminders reminders.');
    }
    await ref.read(settingsControllerProvider.notifier).switchToManualIfAuto();
    await ref.read(reminderRepositoryProvider).add(minuteOfDay: minuteOfDay);
    await _reloadAndSync();
  }

  Future<void> save(Reminder reminder) async {
    await ref.read(settingsControllerProvider.notifier).switchToManualIfAuto();
    // Optimistic update so toggles feel instant.
    final current = state.value;
    if (current != null) {
      state = AsyncData([for (final r in current) r.id == reminder.id ? reminder : r]
        ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay)));
    }
    try {
      await ref.read(reminderRepositoryProvider).update(reminder);
    } finally {
      await _reloadAndSync();
    }
  }

  Future<void> remove(int id) async {
    await ref.read(settingsControllerProvider.notifier).switchToManualIfAuto();
    await ref.read(reminderRepositoryProvider).delete(id);
    await _reloadAndSync();
  }

  Future<void> _reloadAndSync() async {
    state = AsyncData(await ref.read(reminderRepositoryProvider).all());
    await ref.read(notificationSyncProvider).sync();
  }
}

final remindersControllerProvider =
    AsyncNotifierProvider<RemindersController, List<Reminder>>(RemindersController.new);
