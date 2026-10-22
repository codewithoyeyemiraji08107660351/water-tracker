import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

enum ReminderPermission {
  /// Notifications allowed.
  granted,

  /// Never asked yet: show a friendly "Turn on reminders" prompt.
  notAsked,

  /// Asked and refused: only the system settings can turn them back on.
  denied,
}

class PermissionController extends AsyncNotifier<ReminderPermission> {
  @override
  Future<ReminderPermission> build() => _read();

  Future<ReminderPermission> _read() async {
    final enabled = await ref.read(notificationServiceProvider).areEnabled();
    if (enabled) return ReminderPermission.granted;
    return ref.read(settingsRepositoryProvider).notificationPermissionAsked
        ? ReminderPermission.denied
        : ReminderPermission.notAsked;
  }

  /// Re-reads the OS state, e.g. after returning from system settings.
  Future<void> refresh() async {
    state = AsyncData(await _read());
  }

  Future<void> request() async {
    await ref.read(notificationServiceProvider).requestPermission();
    await ref.read(settingsRepositoryProvider).setNotificationPermissionAsked();
    final next = await _read();
    state = AsyncData(next);
    if (next == ReminderPermission.granted) {
      await ref.read(notificationSyncProvider).sync();
    }
  }

  Future<void> openSystemSettings() => ref.read(notificationServiceProvider).openSystemSettings();
}

final permissionControllerProvider =
    AsyncNotifierProvider<PermissionController, ReminderPermission>(PermissionController.new);
