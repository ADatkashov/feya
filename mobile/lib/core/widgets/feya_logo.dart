import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Simple typographic FEYA mark with a five-petal flower symbol.
class FeyaLogo extends StatelessWidget {
  const FeyaLogo({super.key, this.size = 28, this.showWordmark = true});
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FEYA',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: Size.square(size), painter: _PetalPainter()),
          if (showWordmark) ...[
            SizedBox(width: size * 0.32),
            ExcludeSemantics(
              child: Text(
                'FEYA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size * 0.82,
                  fontWeight: FontWeight.w700,
                  letterSpacing: size * 0.12,
                  color: FeyaColors.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = FeyaColors.gradient.createShader(
        Rect.fromCircle(center: c, radius: r),
      )
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 2 * math.pi / 5);
      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(r * 0.55, -r * 0.2, r * 0.45, -r * 0.95, 0, -r)
        ..cubicTo(-r * 0.45, -r * 0.95, -r * 0.55, -r * 0.2, 0, 0)
        ..close();
      canvas.drawPath(
        petal,
        paint..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = FeyaColors.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
