import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/intake_entry.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// Today's logged drinks, newest first.
class TodayIntakeController extends AsyncNotifier<List<IntakeEntry>> {
  @override
  Future<List<IntakeEntry>> build() {
    final day = ref.watch(currentDayProvider);
    return ref.read(intakeRepositoryProvider).forDay(day);
  }

  Future<IntakeEntry> add(int amountMl, {DateTime? at}) async {
    final entry = await ref.read(intakeRepositoryProvider).add(
          amountMl: amountMl,
          loggedAt: at ?? ref.read(clockProvider)(),
        );
    await _afterChange();
    return entry;
  }

  Future<void> edit(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).update(entry);
    await _afterChange();
  }

  Future<void> remove(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).delete(entry.id);
    await _afterChange();
  }

  Future<void> restore(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).restore(entry);
    await _afterChange();
  }

  Future<void> _afterChange() async {
    final day = ref.read(currentDayProvider);
    // Snapshot today's goal so History keeps the right % if the goal changes later.
    await ref.read(goalRepositoryProvider).setGoalForDay(day, ref.read(settingsControllerProvider).goalMl);
    state = AsyncData(await ref.read(intakeRepositoryProvider).forDay(day));
    ref.read(intakeRevisionProvider.notifier).bump();
    await ref.read(notificationSyncProvider).sync();
  }
}

final todayIntakeProvider =
    AsyncNotifierProvider<TodayIntakeController, List<IntakeEntry>>(TodayIntakeController.new);

/// Total ml logged today (0 while loading).
final todayTotalProvider = Provider<int>((ref) {
  final entries = ref.watch(todayIntakeProvider).value ?? const <IntakeEntry>[];
  return entries.fold<int>(0, (sum, e) => sum + e.amountMl);
});
