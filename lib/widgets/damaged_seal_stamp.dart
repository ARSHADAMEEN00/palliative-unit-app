import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A round, textured rubber stamp seal graphic that visually stamps
/// "DAMAGED" over inactive/disabled equipment cards.
class DamagedSealStamp extends StatelessWidget {
  final DateTime? damagedAt;
  final double size;
  final Color color;

  const DamagedSealStamp({
    super.key,
    this.damagedAt,
    this.size = 112,
    this.color = const Color(0xFFE57373),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Damaged equipment',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DamagedSealPainter(damagedAt: damagedAt, color: color),
        ),
      ),
    );
  }
}

class _DamagedSealPainter extends CustomPainter {
  final DateTime? damagedAt;
  final Color color;

  _DamagedSealPainter({required this.damagedAt, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;

    final stampPaint = Paint()
      ..color = color.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final thinPaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Outer Distressed Ring
    _drawDistressedCircle(canvas, center, radius, stampPaint, seed: 1);

    // 2. Inner Concentric Ring
    _drawDistressedCircle(canvas, center, radius - 4.5, thinPaint, seed: 2);

    // 3. Innermost Ring
    _drawDistressedCircle(canvas, center, radius - 17.5, thinPaint, seed: 3);

    // 4. Center Banner for "DAMAGED"
    final bannerHeight = size.height * 0.28;
    final bannerWidth = size.width * 0.94;
    final bannerRect = Rect.fromCenter(
      center: center,
      width: bannerWidth,
      height: bannerHeight,
    );

    // Keep the banner translucent so the mark still feels stamped onto the card.
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(3)),
      bgPaint,
    );

    // Banner Top and Bottom Double Lines
    final bannerLinePaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    _drawDistressedLine(
      canvas,
      Offset(bannerRect.left, bannerRect.top),
      Offset(bannerRect.right, bannerRect.top),
      bannerLinePaint,
      seed: 4,
    );
    _drawDistressedLine(
      canvas,
      Offset(bannerRect.left + 2, bannerRect.top + 2.5),
      Offset(bannerRect.right - 2, bannerRect.top + 2.5),
      thinPaint,
      seed: 5,
    );
    _drawDistressedLine(
      canvas,
      Offset(bannerRect.left, bannerRect.bottom),
      Offset(bannerRect.right, bannerRect.bottom),
      bannerLinePaint,
      seed: 6,
    );
    _drawDistressedLine(
      canvas,
      Offset(bannerRect.left + 2, bannerRect.bottom - 2.5),
      Offset(bannerRect.right - 2, bannerRect.bottom - 2.5),
      thinPaint,
      seed: 7,
    );

    // Banner Left & Right end caps
    canvas.drawLine(
      Offset(bannerRect.left, bannerRect.top),
      Offset(bannerRect.left, bannerRect.bottom),
      bannerLinePaint,
    );
    canvas.drawLine(
      Offset(bannerRect.right, bannerRect.top),
      Offset(bannerRect.right, bannerRect.bottom),
      bannerLinePaint,
    );

    // 5. "DAMAGED" Text in bold distressed serif
    final damagedTextPainter = TextPainter(
      text: TextSpan(
        text: 'DAMAGED',
        style: TextStyle(
          color: color.withValues(alpha: 0.88),
          fontSize: size.width * 0.165,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          letterSpacing: 2.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    damagedTextPainter.paint(
      canvas,
      center -
          Offset(damagedTextPainter.width / 2, damagedTextPainter.height / 2),
    );

    // 6. Top Arc Text
    _drawArcText(
      canvas,
      '★  EQUIPMENT  ★',
      center,
      radius - 11.5,
      -pi / 2,
      isTop: true,
      textStyle: TextStyle(
        color: color.withValues(alpha: 0.75),
        fontSize: size.width * 0.08,
        fontWeight: FontWeight.w800,
        fontFamily: 'serif',
        letterSpacing: 1.0,
      ),
    );

    // 7. Bottom Arc Text: The Date of Damage
    final dateString = damagedAt != null
        ? DateFormat('d MMM yyyy').format(damagedAt!).toUpperCase()
        : 'INSPECTION';
    final bottomText = '★  $dateString  ★';

    _drawArcText(
      canvas,
      bottomText,
      center,
      radius - 11.5,
      pi / 2,
      isTop: false,
      textStyle: TextStyle(
        color: color.withValues(alpha: 0.75),
        fontSize: size.width * 0.075,
        fontWeight: FontWeight.w800,
        fontFamily: 'serif',
        letterSpacing: 0.8,
      ),
    );

    // 8. Distress speckles across the stamp
    _drawDistressSpeckles(canvas, size, color);
  }

  void _drawDistressedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    int seed = 1,
  }) {
    canvas.drawCircle(center, radius, paint);

    final random = Random(seed);
    final notchPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth * 1.3;

    for (int i = 0; i < 5; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final sweep = 0.03 + random.nextDouble() * 0.04;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweep,
        false,
        notchPaint,
      );
    }
  }

  void _drawDistressedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    int seed = 1,
  }) {
    canvas.drawLine(p1, p2, paint);

    final random = Random(seed);
    final notchPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth * 1.3;

    final dx = p2.dx - p1.dx;
    for (int i = 0; i < 3; i++) {
      final t = 0.15 + random.nextDouble() * 0.7;
      final start = p1.dx + dx * t;
      canvas.drawLine(
        Offset(start, p1.dy),
        Offset(start + 2.5, p1.dy),
        notchPaint,
      );
    }
  }

  void _drawArcText(
    Canvas canvas,
    String text,
    Offset center,
    double radius,
    double centerAngle, {
    required bool isTop,
    required TextStyle textStyle,
  }) {
    final painters = <TextPainter>[];
    double totalArc = 0;
    final charAngles = <double>[];

    for (int i = 0; i < text.length; i++) {
      final p = TextPainter(
        text: TextSpan(text: text[i], style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painters.add(p);
      final angle = (p.width + (textStyle.letterSpacing ?? 0)) / radius;
      charAngles.add(angle);
      totalArc += angle;
    }

    double currentAngle;
    if (isTop) {
      currentAngle = centerAngle - (totalArc / 2);
      for (int i = 0; i < text.length; i++) {
        final p = painters[i];
        final sweep = charAngles[i];
        final charCenterAngle = currentAngle + (sweep / 2);

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(charCenterAngle + (pi / 2));
        canvas.translate(0, -radius);
        p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
        canvas.restore();

        currentAngle += sweep;
      }
    } else {
      currentAngle = centerAngle + (totalArc / 2);
      for (int i = 0; i < text.length; i++) {
        final p = painters[i];
        final sweep = charAngles[i];
        final charCenterAngle = currentAngle - (sweep / 2);

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(charCenterAngle - (pi / 2));
        canvas.translate(0, radius);
        p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
        canvas.restore();

        currentAngle -= sweep;
      }
    }
  }

  void _drawDistressSpeckles(Canvas canvas, Size size, Color color) {
    final random = Random(42);
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 28; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = 0.5 + random.nextDouble() * 1.0;
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DamagedSealPainter oldDelegate) {
    return oldDelegate.damagedAt != damagedAt || oldDelegate.color != color;
  }
}
