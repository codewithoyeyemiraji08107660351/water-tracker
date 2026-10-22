import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Friendly water-drop character used on History, drawn in code.
class DropletMascot extends StatelessWidget {
  const DropletMascot({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size * 1.2,
        child: const CustomPaint(painter: _DropletPainter()),
      ),
    );
  }
}

class _DropletPainter extends CustomPainter {
  const _DropletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final drop = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.62, h * 0.22, w * 0.95, h * 0.45, w * 0.95, h * 0.66)
      ..cubicTo(w * 0.95, h * 0.88, w * 0.74, h, w * 0.5, h)
      ..cubicTo(w * 0.26, h, w * 0.05, h * 0.88, w * 0.05, h * 0.66)
      ..cubicTo(w * 0.05, h * 0.45, w * 0.38, h * 0.22, w * 0.5, 0)
      ..close();

    final bounds = Rect.fromLTWH(0, 0, w, h);
    canvas.drawPath(
      drop,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9FDBFA), AppColors.primary],
        ).createShader(bounds),
    );
    canvas.drawPath(
      drop,
      Paint()
        ..color = AppColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03,
    );

    // Highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.32, h * 0.52), width: w * 0.1, height: h * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Eyes
    final white = Paint()..color = Colors.white;
    final pupil = Paint()..color = AppColors.ink;
    for (final x in [0.40, 0.62]) {
      canvas
        ..drawCircle(Offset(w * x, h * 0.62), w * 0.075, white)
        ..drawCircle(Offset(w * (x + 0.015), h * 0.63), w * 0.04, pupil);
    }

    // Smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.51, h * 0.74), width: w * 0.24, height: h * 0.12),
      0.2,
      2.7,
      false,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    // Cheeks
    final cheek = Paint()..color = const Color(0xFFFF9EB5).withValues(alpha: 0.6);
    canvas
      ..drawCircle(Offset(w * 0.28, h * 0.72), w * 0.05, cheek)
      ..drawCircle(Offset(w * 0.76, h * 0.72), w * 0.05, cheek);
  }

  @override
  bool shouldRepaint(_DropletPainter oldDelegate) => false;
}
