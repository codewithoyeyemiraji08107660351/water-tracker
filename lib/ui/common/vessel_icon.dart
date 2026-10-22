import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/models/cup.dart';

/// Line-drawn cup, glass, bottle or jug with an optional water fill.
/// Original artwork drawn in code, so there are no image assets to license.
class VesselIcon extends StatelessWidget {
  const VesselIcon({
    super.key,
    required this.kind,
    this.size = 40,
    this.filled = false,
    this.color = AppColors.ink,
    this.waterColor = AppColors.primary,
  });

  final VesselKind kind;
  final double size;
  final bool filled;
  final Color color;
  final Color waterColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VesselPainter(kind: kind, filled: filled, color: color, waterColor: waterColor),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter({required this.kind, required this.filled, required this.color, required this.waterColor});

  final VesselKind kind;
  final bool filled;
  final Color color;
  final Color waterColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * s, t * s, rr * s, b * s);

    final body = Path();
    final extras = Path();
    switch (kind) {
      case VesselKind.smallCup:
        body.addRRect(RRect.fromRectAndCorners(r(0.16, 0.34, 0.66, 0.82),
            bottomLeft: Radius.circular(0.14 * s), bottomRight: Radius.circular(0.14 * s)));
        extras.addArc(r(0.56, 0.42, 0.82, 0.68), -math.pi / 2, math.pi);
        extras
          ..moveTo(0.08 * s, 0.90 * s)
          ..lineTo(0.78 * s, 0.90 * s);
      case VesselKind.glass:
        body
          ..moveTo(0.22 * s, 0.10 * s)
          ..lineTo(0.78 * s, 0.10 * s)
          ..lineTo(0.70 * s, 0.92 * s)
          ..lineTo(0.30 * s, 0.92 * s)
          ..close();
      case VesselKind.mug:
        body.addRRect(RRect.fromRectAndRadius(r(0.14, 0.18, 0.68, 0.90), Radius.circular(0.07 * s)));
        extras.addArc(r(0.58, 0.32, 0.90, 0.70), -math.pi / 2, math.pi);
      case VesselKind.tallGlass:
        body
          ..moveTo(0.30 * s, 0.04 * s)
          ..lineTo(0.70 * s, 0.04 * s)
          ..lineTo(0.66 * s, 0.96 * s)
          ..lineTo(0.34 * s, 0.96 * s)
          ..close();
      case VesselKind.bottle:
        body
          ..moveTo(0.43 * s, 0.14 * s)
          ..lineTo(0.57 * s, 0.14 * s)
          ..lineTo(0.57 * s, 0.24 * s)
          ..quadraticBezierTo(0.72 * s, 0.30 * s, 0.72 * s, 0.42 * s)
          ..lineTo(0.72 * s, 0.90 * s)
          ..quadraticBezierTo(0.72 * s, 0.96 * s, 0.66 * s, 0.96 * s)
          ..lineTo(0.34 * s, 0.96 * s)
          ..quadraticBezierTo(0.28 * s, 0.96 * s, 0.28 * s, 0.90 * s)
          ..lineTo(0.28 * s, 0.42 * s)
          ..quadraticBezierTo(0.28 * s, 0.30 * s, 0.43 * s, 0.24 * s)
          ..close();
        extras.addRRect(RRect.fromRectAndRadius(r(0.40, 0.04, 0.60, 0.13), Radius.circular(0.02 * s)));
      case VesselKind.jug:
        body
          ..moveTo(0.20 * s, 0.12 * s)
          ..lineTo(0.62 * s, 0.12 * s)
          ..lineTo(0.72 * s, 0.05 * s)
          ..lineTo(0.66 * s, 0.22 * s)
          ..quadraticBezierTo(0.72 * s, 0.40 * s, 0.72 * s, 0.60 * s)
          ..lineTo(0.72 * s, 0.94 * s)
          ..lineTo(0.20 * s, 0.94 * s)
          ..lineTo(0.20 * s, 0.60 * s)
          ..quadraticBezierTo(0.20 * s, 0.36 * s, 0.25 * s, 0.22 * s)
          ..close();
        extras.addArc(r(0.62, 0.30, 0.92, 0.72), -math.pi / 2, math.pi);
    }

    if (filled) {
      final bounds = body.getBounds();
      final waterTop = bounds.top + bounds.height * 0.38;
      canvas
        ..save()
        ..clipPath(body)
        ..drawRect(Rect.fromLTRB(bounds.left, waterTop, bounds.right, bounds.bottom), Paint()..color = waterColor)
        ..restore();
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, s * 0.06)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(body, stroke)
      ..drawPath(extras, stroke);
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.kind != kind || old.filled != filled || old.color != color || old.waterColor != waterColor;
}
