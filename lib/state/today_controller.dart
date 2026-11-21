import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/intake_entry.dart';
import '../domain/services/daily_cap.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// Today's logged drinks, newest first.
class TodayIntakeController extends AsyncNotifier<List<IntakeEntry>> {
  @override
  Future<List<IntakeEntry>> build() {
    final day = ref.watch(currentDayProvider);
    return ref.read(intakeRepositoryProvider).forDay(day);
  }

  /// Logs a drink. With [topUp] (the one-tap button) a cup larger than what is
  /// left logs exactly what is left; otherwise it is refused with a
  /// DailyLimitException once the goal would be passed.
  Future<IntakeEntry> add(int amountMl, {DateTime? at, bool topUp = false}) async {
    final entry = await ref.read(intakeRepositoryProvider).add(
          amountMl: amountMl,
          loggedAt: at ?? ref.read(clockProvider)(),
          dailyGoalMl: _goalMl,
          topUp: topUp,
        );
    await _afterChange();
    return entry;
  }

  Future<void> edit(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).update(entry, dailyGoalMl: _goalMl);
    await _afterChange();
  }

  Future<void> remove(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).delete(entry.id);
    await _afterChange();
  }

  Future<void> restore(IntakeEntry entry) async {
    await ref.read(intakeRepositoryProvider).restore(entry, dailyGoalMl: _goalMl);
    await _afterChange();
  }

  int get _goalMl => ref.read(settingsControllerProvider).goalMl;

  Future<void> _afterChange() async {
    final day = ref.read(currentDayProvider);
    // Snapshot today's goal so History keeps the right % if the goal changes later.
    await ref.read(goalRepositoryProvider).setGoalForDay(day, _goalMl);
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

/// What can still be logged today before the goal is reached.
final todayRemainingProvider = Provider<int>((ref) {
  final goal = ref.watch(settingsControllerProvider.select((s) => s.goalMl));
  return DailyCap.remaining(totalMl: ref.watch(todayTotalProvider), goalMl: goal);
});
