import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/time/time_format.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/user_settings.dart';
import '../../state/providers.dart';
import '../../state/reminders_controller.dart';
import '../../state/settings_controller.dart';
import '../common/state_views.dart';

class ReminderScheduleScreen extends ConsumerStatefulWidget {
  const ReminderScheduleScreen({super.key});

  @override
  ConsumerState<ReminderScheduleScreen> createState() => _ReminderScheduleScreenState();
}

class _ReminderScheduleScreenState extends ConsumerState<ReminderScheduleScreen> {
  int? _expandedId;

  RemindersController get _controller => ref.read(remindersControllerProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on DuplicateReminderException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _add() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'New reminder',
    );
    if (picked == null) return;
    await _run(() => _controller.add(picked.hour * 60 + picked.minute));
  }

  Future<void> _editTime(Reminder r) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
    );
    if (picked == null) return;
    await _run(() => _controller.save(r.copyWith(minuteOfDay: picked.hour * 60 + picked.minute)));
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersControllerProvider);
    final mode = ref.watch(settingsControllerProvider.select((s) => s.reminderMode));
    final dropped = ref.watch(latestPlanProvider.select((p) => p?.dropped ?? 0));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: remindersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load reminders.',
                onRetry: () => ref.invalidate(remindersControllerProvider),
              ),
              data: (reminders) => ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
                    child: Text(
                      mode == ReminderMode.auto
                          ? 'We optimize reminder times based on your drinking history. '
                              'Editing a reminder switches to Manual mode.'
                          : 'Reminders repeat on the days you pick. Turn one off without deleting it.',
                      style: text.bodySmall,
                    ),
                  ),
                  if (dropped > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
                      child: Text(
                        'Your phone holds a limited number of scheduled alerts. The rest are queued '
                        'each time you open the app, so open it at least once a week.',
                        style: text.bodySmall?.copyWith(color: AppColors.primaryDark),
                      ),
                    ),
                  if (reminders.isEmpty)
                    const EmptyView(
                      title: 'No reminders yet',
                      message: 'Tap Add to choose when you want a nudge.',
                      icon: Icons.notifications_none,
                    ),
                  for (final r in reminders)
                    _ReminderTile(
                      reminder: r,
                      expanded: _expandedId == r.id,
                      onToggleExpanded: () => setState(() => _expandedId = _expandedId == r.id ? null : r.id),
                      onEnabledChanged: (v) => _run(() => _controller.save(r.copyWith(enabled: v))),
                      onTimeTap: () => _editTime(r),
                      onWeekdayToggle: (wd) {
                        final next = r.weekdays.toggle(wd);
                        if (next.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Keep at least one day, or turn the reminder off.')),
                          );
                          return;
                        }
                        _run(() => _controller.save(r.copyWith(weekdays: next)));
                      },
                      onDelete: () => _run(() async {
                        setState(() => _expandedId = null);
                        await _controller.remove(r.id);
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEnabledChanged,
    required this.onTimeTap,
    required this.onWeekdayToggle,
    required this.onDelete,
  });

  final Reminder reminder;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onTimeTap;
  final ValueChanged<int> onWeekdayToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final time = TimeFormat.minuteOfDay(context, reminder.minuteOfDay);
    final muted = !reminder.enabled;

    return AnimatedContainer(
      duration: AppDurations.fast,
      color: expanded ? AppColors.surfaceMuted : AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTimeTap,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            time,
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: muted ? AppColors.inkFaint : AppColors.ink,
                            ),
                            semanticsLabel: 'Reminder at $time, tap to change time',
                          ),
                          Text(reminder.weekdays.describe(), style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                Switch(
                  value: reminder.enabled,
                  onChanged: onEnabledChanged,
                ),
                IconButton(
                  tooltip: expanded ? 'Hide options' : 'Show options',
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(Icons.expand_more),
                  ),
                  onPressed: onToggleExpanded,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < 7; i++)
                              _WeekdayChip(
                                letter: TimeFormat.weekdayLetterSunFirst[i],
                                name: TimeFormat.weekdayShortSunFirst[i],
                                selected: reminder.weekdays.contains(i == 0 ? 7 : i),
                                onTap: () => onWeekdayToggle(i == 0 ? 7 : i),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const Divider(indent: AppSpace.lg, endIndent: AppSpace.lg),
        ],
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({required this.letter, required this.name, required this.selected, required this.onTap});

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: AppSizes.touchTarget - 8,
          child: Center(
            child: AnimatedContainer(
              duration: AppDurations.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : AppColors.surface,
                border: Border.all(color: selected ? AppColors.primary : AppColors.line),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.onPrimary : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
