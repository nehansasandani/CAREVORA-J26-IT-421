import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Carevora Ambient Animated Backdrop
///
/// An ethereal, soothing ambient animated background featuring:
/// - Soft breathing pastel aurora orbs
/// - Flowing translucent edge ribbons
/// - Concentric drifting pastel rings
/// - Gently rotating soft rounded hexagons
/// - Twinkling 4-point sparkles
/// - Soft drifting pastel wellness dots
///
/// Designed to be senior-friendly, calming, and performant (using RepaintBoundary).
class CarevoraAmbientBackdrop extends StatefulWidget {
  const CarevoraAmbientBackdrop({super.key});

  @override
  State<CarevoraAmbientBackdrop> createState() => _CarevoraAmbientBackdropState();
}

class _CarevoraAmbientBackdropState extends State<CarevoraAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CarevoraAmbientPainter(progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CarevoraAmbientPainter extends CustomPainter {
  final double progress;

  const _CarevoraAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // 1. Soft breathing pastel aurora orbs around the outer perimeter
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.04 + math.sin(t) * 18,
        size.height * 0.14 + math.cos(t * 0.8) * 20,
      ),
      115,
      const Color(0xFF8B5CF6).withValues(alpha: 0.14),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.96 + math.cos(t) * 18,
        size.height * 0.22 + math.sin(t * 0.9) * 24,
      ),
      125,
      const Color(0xFF14B8A6).withValues(alpha: 0.14),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.05 + math.cos(t * 1.1) * 16,
        size.height * 0.72 + math.sin(t) * 22,
      ),
      120,
      const Color(0xFF38BDF8).withValues(alpha: 0.13),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.95 + math.sin(t * 0.9) * 16,
        size.height * 0.78 + math.cos(t * 1.1) * 20,
      ),
      118,
      const Color(0xFFF472B6).withValues(alpha: 0.13),
    );

    // 2. Delicate flowing translucent ribbons hugging the left & right edges
    _drawEdgeRibbon(
      canvas,
      size,
      isLeft: true,
      phase: t,
      color: const Color(0xFF7C3AED).withValues(alpha: 0.085),
    );
    _drawEdgeRibbon(
      canvas,
      size,
      isLeft: false,
      phase: -t + 1.4,
      color: const Color(0xFF0D9488).withValues(alpha: 0.085),
    );

    // 3. Concentric drifting pastel rings along both side margins
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.045 + math.sin(t + 0.5) * 9,
        size.height * 0.34 + math.cos(t) * 16,
      ),
      26,
      const Color(0xFF7C3AED).withValues(alpha: 0.22),
      innerRing: true,
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.955 + math.cos(t + 1.1) * 9,
        size.height * 0.46 + math.sin(t * 1.2) * 18,
      ),
      30,
      const Color(0xFF0D9488).withValues(alpha: 0.22),
      innerRing: true,
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.065 + math.cos(t * 1.3) * 8,
        size.height * 0.86 + math.sin(t) * 12,
      ),
      20,
      const Color(0xFFEC4899).withValues(alpha: 0.22),
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.94 + math.sin(t * 1.2) * 8,
        size.height * 0.10 + math.cos(t * 1.1) * 12,
      ),
      18,
      const Color(0xFF3B82F6).withValues(alpha: 0.22),
    );

    // 4. Gently rotating soft rounded hexagons on outer borders
    _drawFloatingHexagon(
      canvas,
      Offset(
        size.width * 0.032 + math.cos(t) * 7,
        size.height * 0.56 + math.sin(t * 1.1) * 14,
      ),
      15,
      t * 0.5,
      const Color(0xFF6366F1).withValues(alpha: 0.24),
    );
    _drawFloatingHexagon(
      canvas,
      Offset(
        size.width * 0.965 + math.sin(t * 0.9) * 7,
        size.height * 0.66 + math.cos(t) * 14,
      ),
      16,
      -t * 0.45,
      const Color(0xFF14B8A6).withValues(alpha: 0.24),
    );

    // 5. Twinkling 4-point sparkles along left, right, top corners
    final sparkles = <(double, double, double, Color, double)>[
      (0.03, 0.22, 8.5, const Color(0xFF8B5CF6), 0.0),
      (0.075, 0.44, 6.5, const Color(0xFF0EA5E9), 1.3),
      (0.04, 0.68, 7.5, const Color(0xFFEC4899), 2.5),
      (0.08, 0.92, 6.0, const Color(0xFF14B8A6), 3.7),
      (0.965, 0.16, 8.0, const Color(0xFF14B8A6), 0.8),
      (0.925, 0.34, 6.5, const Color(0xFF8B5CF6), 2.1),
      (0.96, 0.58, 8.5, const Color(0xFF3B82F6), 3.3),
      (0.93, 0.84, 7.0, const Color(0xFFF43F5E), 4.6),
    ];

    for (final s in sparkles) {
      final pulse = 0.55 + 0.45 * math.sin(t * 2 + s.$5);
      final cx = size.width * s.$1 + math.sin(t + s.$5) * 6;
      final cy = size.height * s.$2 + math.cos(t + s.$5) * 9;
      _drawSparkle(
        canvas,
        Offset(cx, cy),
        s.$3 * (0.78 + 0.28 * pulse),
        s.$4.withValues(alpha: 0.20 + 0.32 * pulse),
      );
    }

    // 6. Soft drifting pastel wellness dots around the outer frame
    final dots = <(double, double, double, Color, double)>[
      (0.055, 0.12, 4.5, const Color(0xFF6366F1), 0.4),
      (0.025, 0.48, 3.8, const Color(0xFF14B8A6), 1.9),
      (0.068, 0.77, 4.2, const Color(0xFFF59E0B), 3.1),
      (0.945, 0.28, 4.4, const Color(0xFFEC4899), 1.1),
      (0.972, 0.74, 3.8, const Color(0xFF6366F1), 2.7),
      (0.935, 0.91, 4.6, const Color(0xFF0EA5E9), 4.2),
    ];

    for (final d in dots) {
      final dotPaint = Paint()
        ..color = d.$4.withValues(
          alpha: 0.22 + 0.14 * math.sin(t * 1.5 + d.$5),
        );
      canvas.drawCircle(
        Offset(
          size.width * d.$1 + math.cos(t + d.$5) * 8,
          size.height * d.$2 + math.sin(t * 1.2 + d.$5) * 11,
        ),
        d.$3,
        dotPaint,
      );
    }
  }

  void _drawGlowOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawEdgeRibbon(
    Canvas canvas,
    Size size, {
    required bool isLeft,
    required double phase,
    required Color color,
  }) {
    final path = Path();
    final baseX = isLeft ? 14.0 : size.width - 14.0;
    final dir = isLeft ? 1.0 : -1.0;
    const steps = 28;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final y = size.height * frac;
      final wave = math.sin(frac * math.pi * 3 + phase) * 14 * dir +
          math.cos(frac * math.pi * 2 - phase * 0.7) * 8 * dir;
      final x = baseX + wave;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  void _drawFloatingRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    bool innerRing = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius, paint);
    if (innerRing) {
      canvas.drawCircle(
        center,
        radius * 0.56,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFloatingHexagon(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      final pt = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CarevoraAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
