import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/auto_schedule_runner.dart';
import '../application/notification_sync.dart';
import '../core/time/local_day.dart';
import '../data/db/app_database.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/intake_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/services/reminder_planner.dart';
import '../infrastructure/notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Infrastructure. These three are created in main() and injected with
// overrides, so tests can swap in fakes.
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden in main()'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError('notificationServiceProvider must be overridden in main()'),
);

/// Injectable clock for deterministic tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final intakeRepositoryProvider = Provider<IntakeRepository>(
  (ref) => IntakeRepository(ref.watch(databaseProvider).db, now: ref.watch(clockProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(ref.watch(databaseProvider).db, now: ref.watch(clockProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(databaseProvider).db),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

// ---------------------------------------------------------------------------
// Application services
// ---------------------------------------------------------------------------

/// The plan from the most recent notification sync (drives "next reminder" on Home).
class LatestPlan extends Notifier<ReminderPlan?> {
  @override
  ReminderPlan? build() => null;

  void set(ReminderPlan plan) => state = plan;
}

final latestPlanProvider = NotifierProvider<LatestPlan, ReminderPlan?>(LatestPlan.new);

final notificationSyncProvider = Provider<NotificationSync>((ref) {
  return NotificationSync(
    intake: ref.watch(intakeRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    service: ref.watch(notificationServiceProvider),
    onPlanned: (plan) => ref.read(latestPlanProvider.notifier).set(plan),
    now: ref.watch(clockProvider),
  );
});

final autoScheduleRunnerProvider = Provider<AutoScheduleRunner>((ref) {
  return AutoScheduleRunner(
    intake: ref.watch(intakeRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    now: ref.watch(clockProvider),
  );
});

// ---------------------------------------------------------------------------
// Shared app state
// ---------------------------------------------------------------------------

/// The current local day. Refreshed on app resume and at midnight so "today"
/// rolls over without restarting the app.
class CurrentDay extends Notifier<LocalDay> {
  @override
  LocalDay build() => LocalDay.fromDateTime(ref.read(clockProvider)());

  /// Returns true when the day changed.
  bool refresh() {
    final now = LocalDay.fromDateTime(ref.read(clockProvider)());
    if (now == state) return false;
    state = now;
    return true;
  }
}

final currentDayProvider = NotifierProvider<CurrentDay, LocalDay>(CurrentDay.new);

/// Bumped on every intake change so history views recompute.
class IntakeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final intakeRevisionProvider = NotifierProvider<IntakeRevision, int>(IntakeRevision.new);
