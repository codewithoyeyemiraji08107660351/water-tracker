import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../state/permission_controller.dart';
import '../../state/providers.dart';
import '../../state/reminders_controller.dart';
import '../../state/settings_controller.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

/// Top-level layout from the prototype: blue bar with Home / History / Settings tabs.
///
/// Also owns app-lifecycle housekeeping: on launch, on resume and at midnight
/// it refreshes "today", the time zone, the Auto schedule and the notification queue.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _housekeeping(refreshTimeZone: false));
    _scheduleMidnightTick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_housekeeping(refreshTimeZone: true));
      unawaited(ref.read(permissionControllerProvider.notifier).refresh());
      _scheduleMidnightTick();
    }
  }

  void _scheduleMidnightTick() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      unawaited(_housekeeping(refreshTimeZone: false));
      _scheduleMidnightTick();
    });
  }

  Future<void> _housekeeping({required bool refreshTimeZone}) async {
    try {
      if (refreshTimeZone) await ref.read(notificationServiceProvider).refreshTimeZone();
      if (!mounted) return;

      final dayChanged = ref.read(currentDayProvider.notifier).refresh();
      final day = ref.read(currentDayProvider);
      await ref.read(goalRepositoryProvider).setGoalForDay(day, ref.read(settingsControllerProvider).goalMl);
      if (dayChanged) ref.read(intakeRevisionProvider.notifier).bump();

      final rebuilt = await ref.read(autoScheduleRunnerProvider).run();
      if (rebuilt && mounted) ref.invalidate(remindersControllerProvider);

      await ref.read(notificationSyncProvider).sync();
    } catch (e, st) {
      debugPrint('Housekeeping failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Drink Water Reminder'),
          bottom: const TabBar(
            labelColor: AppColors.onPrimary,
            unselectedLabelColor: Color(0xDDFFFFFF),
            indicatorColor: AppColors.onPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.water_drop, size: 20), text: 'Home', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.history, size: 20), text: 'History', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings', iconMargin: EdgeInsets.only(bottom: 2)),
            ],
          ),
        ),
        body: const SafeArea(
          top: false,
          child: TabBarView(
            children: [HomeScreen(), HistoryScreen(), SettingsScreen()],
          ),
        ),
      ),
    );
  }
}
