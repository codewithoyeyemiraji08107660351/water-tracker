import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/units/volume.dart';

/// Circular progress ring with an animated water level inside.
class HydrationRing extends StatefulWidget {
  const HydrationRing({
    super.key,
    required this.totalMl,
    required this.goalMl,
    required this.unit,
    this.size = AppSizes.progressRing,
  });

  final int totalMl;
  final int goalMl;
  final UnitSystem unit;
  final double size;

  @override
  State<HydrationRing> createState() => _HydrationRingState();
}

class _HydrationRingState extends State<HydrationRing> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.goalMl <= 0 ? 0.0 : widget.totalMl / widget.goalMl;
    final pct = (progress * 100).round();
    final text = Theme.of(context).textTheme;
    final unitLabel = Volume.unitLabel(widget.unit);

    return Semantics(
      label: '${Volume.format(widget.totalMl, widget.unit)} of ${Volume.format(widget.goalMl, widget.unit)}, '
          '$pct percent of today\'s goal',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, _) => AnimatedBuilder(
            animation: _wave,
            builder: (context, _) => CustomPaint(
              painter: _RingPainter(progress: animatedProgress, wavePhase: _wave.value * 2 * math.pi),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: Volume.format(widget.totalMl, widget.unit, withUnit: false),
                          style: text.headlineSmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' / ${Volume.format(widget.goalMl, widget.unit, withUnit: false)} $unitLabel',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text('$pct%', style: text.bodySmall?.copyWith(color: AppColors.ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.wavePhase});

  final double progress;
  final double wavePhase;

  static const _stroke = 10.0;
  static const _gap = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= (_stroke + _gap) * 2) return;
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - _stroke / 2;
    final innerRadius = ringRadius - _stroke / 2 - _gap;

    // Inner disc with water.
    final inner = Rect.fromCircle(center: center, radius: innerRadius);
    canvas
      ..save()
      ..clipPath(Path()..addOval(inner))
      ..drawRect(inner, Paint()..color = const Color(0xFFF1F3F5));

    final waterTop = inner.bottom - inner.height * progress;
    _drawWave(canvas, inner, waterTop, amplitude: 5, phase: wavePhase + math.pi,
        color: AppColors.primary.withValues(alpha: 0.35));
    _drawWave(canvas, inner, waterTop + 3, amplitude: 6, phase: wavePhase,
        color: AppColors.primary.withValues(alpha: 0.55));
    canvas.restore();

    // Track and progress arc.
    final arcRect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = AppColors.primarySoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke,
      );
    }
  }

  void _drawWave(Canvas canvas, Rect area, double top,
      {required double amplitude, required double phase, required Color color}) {
    if (progress <= 0) return;
    final path = Path()..moveTo(area.left, area.bottom);
    const segments = 40;
    for (var i = 0; i <= segments; i++) {
      final x = area.left + area.width * i / segments;
      final y = top + math.sin(i / segments * 2 * math.pi + phase) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(area.right, area.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.wavePhase != wavePhase;
}
