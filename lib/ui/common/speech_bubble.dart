import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

enum BubbleTail { left, right }

/// Outlined speech bubble with a small tail, as used for tips in the prototype.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.tail = BubbleTail.right});

  final String text;
  final BubbleTail tail;

  static const _tailWidth = 14.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(tail),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg + (tail == BubbleTail.left ? _tailWidth : 0),
          AppSpace.md,
          AppSpace.lg + (tail == BubbleTail.right ? _tailWidth : 0),
          AppSpace.md,
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.tail);

  final BubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    const tw = SpeechBubble._tailWidth;
    final left = tail == BubbleTail.left ? tw : 0.0;
    final right = size.width - (tail == BubbleTail.right ? tw : 0.0);
    final body = RRect.fromLTRBR(left, 0, right, size.height, const Radius.circular(AppRadius.md));

    final path = Path()..addRRect(body);
    final tailY = size.height * 0.28;
    if (tail == BubbleTail.right) {
      path
        ..moveTo(right - 1, tailY)
        ..lineTo(size.width, tailY - 8)
        ..lineTo(right - 1, tailY + 12);
    } else {
      path
        ..moveTo(left + 1, tailY)
        ..lineTo(0, tailY - 8)
        ..lineTo(left + 1, tailY + 12);
    }

    canvas
      ..drawPath(path, Paint()..color = AppColors.surface)
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.tail != tail;
}
