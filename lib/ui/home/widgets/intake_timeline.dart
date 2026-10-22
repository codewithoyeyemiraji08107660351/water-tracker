import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/time_format.dart';
import '../../../core/units/volume.dart';
import '../../../domain/models/cup.dart';
import '../../../domain/models/intake_entry.dart';
import '../../common/vessel_icon.dart';

enum EntryAction { edit, delete }

/// Vertical timeline: the next reminder on top, then today's drinks, joined by
/// a dotted line, matching the prototype's Home screen.
class IntakeTimeline extends StatelessWidget {
  const IntakeTimeline({
    super.key,
    required this.entries,
    required this.nextReminder,
    required this.cupMl,
    required this.unit,
    required this.onAction,
  });

  final List<IntakeEntry> entries;
  final DateTime? nextReminder;
  final int cupMl;
  final UnitSystem unit;
  final void Function(IntakeEntry entry, EntryAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final total = entries.length + (nextReminder != null ? 1 : 0);
    var index = 0;

    if (nextReminder != null) {
      rows.add(_TimelineRow(
        isLast: index == total - 1,
        leading: const Icon(Icons.schedule, size: 22, color: AppColors.primary),
        time: TimeFormat.dateTime(context, nextReminder!),
        amount: Volume.format(cupMl, unit),
        caption: 'Next reminder',
        muted: true,
      ));
      index++;
    }

    for (final e in entries) {
      rows.add(_TimelineRow(
        isLast: index == total - 1,
        leading: VesselIcon(kind: CupPreset.kindFor(e.amountMl), size: 22, filled: true),
        time: TimeFormat.dateTime(context, e.loggedAt),
        amount: Volume.format(e.amountMl, unit),
        trailing: PopupMenuButton<EntryAction>(
          tooltip: 'Drink options',
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (a) => onAction(e, a),
          itemBuilder: (_) => const [
            PopupMenuItem(value: EntryAction.edit, child: Text('Edit')),
            PopupMenuItem(
              value: EntryAction.delete,
              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ));
      index++;
    }

    return Column(children: rows);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.isLast,
    required this.leading,
    required this.time,
    required this.amount,
    this.caption,
    this.trailing,
    this.muted = false,
  });

  final bool isLast;
  final Widget leading;
  final String time;
  final String amount;
  final String? caption;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = muted ? AppColors.inkMuted : AppColors.ink;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: AppSpace.md),
                leading,
                if (!isLast) const Expanded(child: _DottedLine()),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.touchTarget + AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time, style: text.bodyMedium?.copyWith(color: color)),
                        if (caption != null) Text(caption!, style: text.labelSmall),
                      ],
                    ),
                  ),
                  Text(amount, style: text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500)),
                  SizedBox(width: AppSizes.touchTarget, child: trailing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _DotsPainter(), size: Size(2, double.infinity));
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.inkMuted;
    for (var y = 4.0; y < size.height - 2; y += 6) {
      canvas.drawCircle(Offset(size.width / 2, y), 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}
