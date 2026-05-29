import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated sci-fi grid + particles background.
class SciFiBackground extends StatefulWidget {
  const SciFiBackground({super.key});

  @override
  State<SciFiBackground> createState() => _SciFiBackgroundState();
}

class _SciFiBackgroundState extends State<SciFiBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SciFiPainter(_ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SciFiPainter extends CustomPainter {
  final double t;
  _SciFiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---- gradient fill ----
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0B0E1E),
          Color(0xFF141832),
          Color(0xFF1A1F3A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ---- grid ----
    final gridPaint = Paint()
      ..color = const Color(0xFF3A3F6E).withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    const gridSize = 40.0;
    for (double x = 0; x < w; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ---- particles ----
    final rng = math.Random(42);
    final particlePaint = Paint()..style = PaintingStyle.fill;
    const colors = [
      Color(0xFF7C8FFF),
      Color(0xFFA78BFA),
      Color(0xFF60A5FA),
    ];

    for (int i = 0; i < 40; i++) {
      // deterministic "random" positions animated by t
      final baseX = rng.nextDouble() * w;
      final baseY = rng.nextDouble() * h;
      final px = (baseX + math.sin(t * math.pi * 2 + i) * 30) % w;
      final py = (baseY + math.cos(t * math.pi * 2 + i * 1.3) * 20) % h;
      final radius = 1.0 + rng.nextDouble() * 2.0;
      final brightness = 0.3 + rng.nextDouble() * 0.7;

      particlePaint.color =
          colors[i % colors.length].withValues(alpha: brightness);
      canvas.drawCircle(Offset(px, py), radius, particlePaint);
    }

    // ---- accent lines at bottom ----
    final accentPaint = Paint()
      ..color = const Color(0xFF7C8FFF).withValues(alpha: 0.15)
      ..strokeWidth = 1;
    final lineY = h - 60 + math.sin(t * math.pi * 2) * 4;
    canvas.drawLine(Offset(20, lineY), Offset(w - 20, lineY), accentPaint);
  }

  @override
  bool shouldRepaint(covariant _SciFiPainter old) => old.t != t;
}
