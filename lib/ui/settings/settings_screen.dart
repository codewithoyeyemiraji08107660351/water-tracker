import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/units/volume.dart';
import '../../domain/models/user_settings.dart';
import '../../domain/services/hydration_goal.dart';
import '../../state/permission_controller.dart';
import '../../state/reminders_controller.dart';
import '../../state/settings_controller.dart';
import '../common/state_views.dart';
import '../reminders/reminder_schedule_screen.dart';
import 'widgets/settings_sheets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final reminderCount = ref.watch(remindersControllerProvider).value?.where((r) => r.isActive).length;
    final permission = ref.watch(permissionControllerProvider).value;
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> apply(UserSettings Function(UserSettings) change) async {
      try {
        await controller.update(change);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Reminder settings'),
                _ValueTile(
                  title: 'Reminder schedule',
                  value: reminderCount == null ? null : '$reminderCount active',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ReminderScheduleScreen()),
                  ),
                  chevron: true,
                ),
                _ValueTile(
                  title: 'Reminder sound',
                  value: s.reminderSound.label,
                  onTap: () async {
                    final v = await showChoiceSheet<ReminderSound>(
                      context,
                      title: 'Reminder sound',
                      selected: s.reminderSound,
                      options: [for (final o in ReminderSound.values) ChoiceOption(o, o.label)],
                    );
                    if (v != null) await apply((x) => x.copyWith(reminderSound: v));
                  },
                ),
                _ValueTile(
                  title: 'Reminder mode',
                  value: s.reminderMode.label,
                  onTap: () async {
                    final v = await showChoiceSheet<ReminderMode>(
                      context,
                      title: 'Reminder mode',
                      selected: s.reminderMode,
                      options: const [
                        ChoiceOption(
                          ReminderMode.auto,
                          'Auto',
                          description: 'Times adapt to when you usually drink, rebuilt daily. Replaces your current list.',
                        ),
                        ChoiceOption(
                          ReminderMode.manual,
                          'Manual',
                          description: 'You set every reminder yourself.',
                        ),
                      ],
                    );
                    if (v != null) await apply((x) => x.copyWith(reminderMode: v));
                  },
                ),
                SwitchListTile(
                  title: const Text('Reminder alert'),
                  subtitle: const Text('Remind you again when you missed the intake time'),
                  value: s.missedIntakeAlert,
                  onChanged: (v) => apply((x) => x.copyWith(missedIntakeAlert: v)),
                ),
                SwitchListTile(
                  title: const Text('Further reminder'),
                  subtitle: const Text('Still remind you after your goal is achieved'),
                  value: s.remindAfterGoal,
                  onChanged: (v) => apply((x) => x.copyWith(remindAfterGoal: v)),
                ),
                _ValueTile(
                  title: 'Notifications',
                  value: switch (permission) {
                    ReminderPermission.granted => 'Allowed',
                    ReminderPermission.denied => 'Blocked',
                    ReminderPermission.notAsked => 'Not set up',
                    null => null,
                  },
                  onTap: () {
                    final c = ref.read(permissionControllerProvider.notifier);
                    if (permission == ReminderPermission.notAsked) {
                      c.request();
                    } else {
                      c.openSystemSettings();
                    }
                  },
                ),
                const SectionHeader('General'),
                _ValueTile(
                  title: 'Unit',
                  value: s.unit.label,
                  onTap: () async {
                    final v = await showChoiceSheet<UnitSystem>(
                      context,
                      title: 'Unit',
                      selected: s.unit,
                      options: [for (final u in UnitSystem.values) ChoiceOption(u, u.label)],
                    );
                    if (v != null) await apply((x) => x.copyWith(unit: v));
                  },
                ),
                _ValueTile(
                  title: 'Intake goal',
                  value: Volume.format(s.goalMl, s.unit),
                  onTap: () async {
                    final suggested = HydrationGoal.suggestMl(gender: s.gender, weightKg: s.weightKg);
                    final v = await showNumberSheet(
                      context,
                      title: 'Daily intake goal',
                      label: 'Goal',
                      suffix: Volume.unitLabel(s.unit),
                      decimal: s.unit == UnitSystem.imperial,
                      initial: Volume.fromMl(s.goalMl, s.unit),
                      helper: 'A starting point, not medical advice. Ask your doctor if you have a '
                          'condition that affects how much you should drink.',
                      suggestion: (
                        label: 'Use suggested ${Volume.format(suggested, s.unit)}',
                        value: Volume.fromMl(suggested, s.unit),
                      ),
                      validate: (value) {
                        final ml = Volume.toMl(value, s.unit);
                        if (ml < UserSettings.minGoalMl || ml > UserSettings.maxGoalMl) {
                          return 'Choose between ${Volume.format(UserSettings.minGoalMl, s.unit)} '
                              'and ${Volume.format(UserSettings.maxGoalMl, s.unit)}.';
                        }
                        return null;
                      },
                    );
                    if (v != null) await apply((x) => x.copyWith(goalMl: Volume.toMl(v, s.unit)));
                  },
                ),
                _ValueTile(
                  title: 'Language',
                  value: 'English',
                  onTap: () => showChoiceSheet<String>(
                    context,
                    title: 'Language',
                    selected: 'en',
                    options: const [
                      ChoiceOption('en', 'English', description: 'More languages are planned.'),
                    ],
                  ),
                ),
                const SectionHeader('Personal data'),
                _ValueTile(
                  title: 'Gender',
                  value: s.gender?.label ?? 'Not set',
                  onTap: () async {
                    final v = await showChoiceSheet<Gender>(
                      context,
                      title: 'Gender',
                      selected: s.gender,
                      options: [for (final g in Gender.values) ChoiceOption(g, g.label)],
                    );
                    if (v != null) await apply((x) => x.copyWith(gender: v));
                  },
                ),
                _ValueTile(
                  title: 'Weight',
                  value: s.weightKg == null
                      ? 'Not set'
                      : '${Volume.weightFromKg(s.weightKg!, s.unit).toStringAsFixed(0)} '
                          '${Volume.weightUnitLabel(s.unit)}',
                  onTap: () async {
                    final v = await showNumberSheet(
                      context,
                      title: 'Weight',
                      label: 'Weight',
                      suffix: Volume.weightUnitLabel(s.unit),
                      decimal: true,
                      initial: s.weightKg == null ? null : Volume.weightFromKg(s.weightKg!, s.unit),
                      helper: 'Used only to suggest a goal. Stays on this phone.',
                      validate: (value) {
                        final kg = Volume.weightToKg(value, s.unit);
                        return kg < 20 || kg > 300 ? 'Enter a realistic weight.' : null;
                      },
                    );
                    if (v != null) await apply((x) => x.copyWith(weightKg: Volume.weightToKg(v, s.unit)));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  child: Text(
                    'Your data is stored only on this device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.title, required this.value, required this.onTap, this.chevron = false});

  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      title: Text(title, style: text.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: text.bodyMedium?.copyWith(color: AppColors.primaryDark)),
          if (chevron) const Icon(Icons.chevron_right, color: AppColors.inkFaint),
        ],
      ),
      onTap: onTap,
    );
  }
}
