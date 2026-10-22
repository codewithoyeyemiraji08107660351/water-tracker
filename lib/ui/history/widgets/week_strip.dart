import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/time_format.dart';
import '../../../domain/models/cup.dart';
import '../../../domain/services/stats_calculator.dart';
import '../../common/vessel_icon.dart';

/// Sunday-to-Saturday strip; a check badge marks days where the goal was met.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.week});

  /// Seven entries, Sunday first. Null = a future day.
  final List<DayTotal?> week;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Week', style: text.bodySmall?.copyWith(color: AppColors.ink)),
          const SizedBox(height: AppSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _DayDot(label: TimeFormat.weekdayShortSunFirst[i], day: week[i])),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.day});

  final String label;
  final DayTotal? day;

  @override
  Widget build(BuildContext context) {
    final met = day?.goalMet ?? false;
    final future = day == null;
    final pct = day == null ? null : (day!.completion * 100).round();

    return Semantics(
      label: future ? '$label, upcoming' : '$label, $pct percent${met ? ', goal met' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: met ? AppColors.primary : AppColors.inkFaint.withValues(alpha: future ? 0.25 : 0.55),
                  ),
                  alignment: Alignment.center,
                  child: VesselIcon(
                    kind: VesselKind.glass,
                    size: 18,
                    filled: met,
                    color: AppColors.onPrimary,
                    waterColor: AppColors.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
                if (met)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: AppColors.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}
