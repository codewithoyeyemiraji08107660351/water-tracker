import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/units/volume.dart';
import '../../domain/models/cup.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../common/speech_bubble.dart';
import '../common/vessel_icon.dart';
import '../home/widgets/amount_sheet.dart';

/// "Switch cup": choose the size the quick-add button logs.
class SwitchCupScreen extends ConsumerWidget {
  const SwitchCupScreen({super.key});

  static String tipFor(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'Start your morning with a glass of water before coffee.';
    if (h < 15) return 'How about having a cup of water after lunch?';
    if (h < 19) return 'An afternoon glass helps beat the slump.';
    return 'Go for a small cup this late, so sleep stays undisturbed.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final isPreset = CupPreset.all.any((p) => p.ml == settings.cupMl);
    final text = Theme.of(context).textTheme;

    Future<void> select(int ml) async {
      final navigator = Navigator.of(context);
      await ref.read(settingsControllerProvider.notifier).update((s) => s.copyWith(cupMl: ml));
      if (navigator.mounted) navigator.pop();
    }

    Future<void> custom() async {
      final now = ref.read(clockProvider)();
      final result = await showAmountSheet(
        context,
        unit: settings.unit,
        initialMl: settings.cupMl,
        initialTime: now,
        now: now,
        editing: true,
        title: 'Custom cup size',
        submitLabel: 'Use this size',
        showTime: false,
        maxMl: null,
      );
      if (result != null && context.mounted) await select(result.amountMl);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Switch cup')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpace.md,
                  crossAxisSpacing: AppSpace.md,
                  childAspectRatio: 0.95,
                  children: [
                    for (final preset in CupPreset.all)
                      _CupTile(
                        label: Volume.format(preset.ml, settings.unit),
                        semanticLabel: '${preset.label}, ${Volume.format(preset.ml, settings.unit)}',
                        selected: settings.cupMl == preset.ml,
                        icon: VesselIcon(kind: preset.kind, size: 44, filled: settings.cupMl == preset.ml),
                        onTap: () => select(preset.ml),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _CupTile(
                  label: isPreset ? 'Custom size' : 'Custom: ${Volume.format(settings.cupMl, settings.unit)}',
                  semanticLabel: 'Choose a custom cup size',
                  selected: !isPreset,
                  icon: const Icon(Icons.tune, size: 28),
                  onTap: custom,
                  horizontal: true,
                ),
                const SizedBox(height: AppSpace.xxl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: SpeechBubble(text: tipFor(ref.read(clockProvider)())),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'The Drink button on Home logs this amount in one tap.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CupTile extends StatelessWidget {
  const _CupTile({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.horizontal = false,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = [
      icon,
      SizedBox(width: horizontal ? AppSpace.md : 0, height: horizontal ? 0 : AppSpace.sm),
      Text(label, style: text.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
    ];

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: horizontal
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: children)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ),
      ),
    );
  }
}
