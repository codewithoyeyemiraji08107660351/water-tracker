import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/units/volume.dart';
import '../../domain/models/cup.dart';
import '../../domain/models/intake_entry.dart';
import '../../domain/models/user_settings.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../../state/today_controller.dart';
import '../common/speech_bubble.dart';
import '../common/state_views.dart';
import '../common/vessel_icon.dart';
import '../cups/switch_cup_screen.dart';
import 'widgets/amount_sheet.dart';
import 'widgets/hydration_ring.dart';
import 'widgets/intake_timeline.dart';
import 'widgets/permission_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final todayAsync = ref.watch(todayIntakeProvider);
    final total = ref.watch(todayTotalProvider);
    final plan = ref.watch(latestPlanProvider);
    final now = ref.read(clockProvider)();
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PermissionBanner(),
              const SizedBox(height: AppSpace.xl),
              Text("Let's drink some water", style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  const side = 64.0;
                  final ringSize = (constraints.maxWidth - side * 2).clamp(0.0, AppSizes.progressRing);
                  if (ringSize < 80) return const SizedBox(height: AppSizes.progressRing);
                  return Row(
                    children: [
                      const SizedBox(width: side),
                      Expanded(
                        child: Center(
                          child: HydrationRing(
                            totalMl: total,
                            goalMl: settings.goalMl,
                            unit: settings.unit,
                            size: ringSize,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: side,
                        child: _SwitchCupButton(settings: settings),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpace.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _quickAdd(context, ref, settings, total),
                      icon: VesselIcon(
                        kind: CupPreset.kindFor(settings.cupMl),
                        size: 20,
                        filled: true,
                        color: AppColors.onPrimary,
                        waterColor: AppColors.onPrimary.withValues(alpha: 0.6),
                      ),
                      label: Text('Drink ${Volume.format(settings.cupMl, settings.unit)}'),
                    ),
                    TextButton(
                      onPressed: () => _customAdd(context, ref, settings, total),
                      child: const Text('Other amount'),
                    ),
                  ],
                ),
              ),
              if (total >= settings.goalMl) ...[
                const SizedBox(height: AppSpace.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpace.xl),
                  child: SpeechBubble(
                    text: 'Goal reached for today. Keep sipping if you are thirsty.',
                    tail: BubbleTail.left,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Text('TODAY', style: text.labelMedium),
              ),
              const SizedBox(height: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: todayAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(AppSpace.xl), child: LoadingView()),
                  error: (e, _) => ErrorView(
                    message: 'Could not load today\'s drinks.',
                    onRetry: () => ref.invalidate(todayIntakeProvider),
                  ),
                  data: (entries) {
                    final next = plan?.nextReminderToday(now);
                    if (entries.isEmpty && next == null) {
                      return const EmptyView(
                        title: 'No drinks yet today',
                        message: 'Tap the button above each time you have a glass.',
                      );
                    }
                    return IntakeTimeline(
                      entries: entries,
                      nextReminder: next,
                      cupMl: settings.cupMl,
                      unit: settings.unit,
                      onAction: (entry, action) => _onEntryAction(context, ref, settings, entry, action),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref, UserSettings settings, int totalBefore) async {
    await HapticFeedback.lightImpact();
    await _log(context, ref, settings, totalBefore, settings.cupMl, null);
  }

  Future<void> _customAdd(BuildContext context, WidgetRef ref, UserSettings settings, int totalBefore) async {
    final now = ref.read(clockProvider)();
    final result = await showAmountSheet(
      context,
      unit: settings.unit,
      initialMl: settings.cupMl,
      initialTime: now,
      now: now,
    );
    if (result == null || !context.mounted) return;
    await _log(context, ref, settings, totalBefore, result.amountMl, result.loggedAt);
  }

  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
    int totalBefore,
    int amountMl,
    DateTime? at,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(todayIntakeProvider.notifier).add(amountMl, at: at);
      if (totalBefore < settings.goalMl && totalBefore + amountMl >= settings.goalMl) {
        messenger.showSnackBar(const SnackBar(content: Text('Daily goal reached. Nice work.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _onEntryAction(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
    IntakeEntry entry,
    EntryAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(todayIntakeProvider.notifier);
    try {
      switch (action) {
        case EntryAction.edit:
          final result = await showAmountSheet(
            context,
            unit: settings.unit,
            initialMl: entry.amountMl,
            initialTime: entry.loggedAt,
            now: ref.read(clockProvider)(),
            editing: true,
          );
          if (result == null) return;
          await controller.edit(entry.copyWith(amountMl: result.amountMl, loggedAt: result.loggedAt));
        case EntryAction.delete:
          await controller.remove(entry);
          messenger.showSnackBar(SnackBar(
            content: Text('Removed ${Volume.format(entry.amountMl, settings.unit)}'),
            action: SnackBarAction(label: 'Undo', onPressed: () => controller.restore(entry)),
          ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _SwitchCupButton extends StatelessWidget {
  const _SwitchCupButton({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Switch cup',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SwitchCupScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VesselIcon(kind: CupPreset.kindFor(settings.cupMl), size: 28, filled: true),
              const SizedBox(height: AppSpace.xs),
              Text(
                Volume.format(settings.cupMl, settings.unit),
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
