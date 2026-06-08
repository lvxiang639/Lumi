import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const AppLogo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(
        size: Size(size, size),
        painter: _LingxiLogoPainter(),
      ),
      if (showText) ...[
        const SizedBox(height: 12),
        Text('灵犀', style: TextStyle(
          fontSize: size * 0.35, fontWeight: FontWeight.w700,
          color: AppColors.textLight, letterSpacing: 4)),
        const SizedBox(height: 4),
        Text('心有灵犀一点通', style: TextStyle(
          fontSize: size * 0.14, color: AppColors.textLightSecondary)),
      ],
    ]);
  }
}

class _LingxiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final scale = size.width / 1024;

    // Background circle
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF6C63FF), Color(0xFF4834B5)]
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(Offset(cx, cy), size.width / 2, bgPaint);

    // Soft inner glow
    final glowPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.38, glowPaint);

    // Horn (golden — the magic)
    final hornPath = Path();
    hornPath.moveTo(cx - 15 * scale, cy - 100 * scale);
    hornPath.lineTo(cx + 5 * scale, cy - 280 * scale);
    hornPath.lineTo(cx + 25 * scale, cy - 100 * scale);
    hornPath.close();
    final hornPaint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawPath(hornPath, hornPaint);

    // Horn glow
    final hornGlow = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawPath(hornPath, hornGlow);

    // Head
    final headPaint = Paint()..color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 20 * scale), width: 200 * scale, height: 180 * scale),
      headPaint);

    // Ear
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 80 * scale, cy - 50 * scale), width: 60 * scale, height: 70 * scale),
      headPaint);

    // Eye
    final eyePaint = Paint()..color = const Color(0xFF4834B5);
    canvas.drawCircle(Offset(cx - 30 * scale, cy - 10 * scale), 10 * scale, eyePaint);
    canvas.drawCircle(Offset(cx - 26 * scale, cy - 13 * scale), 3 * scale, Paint()..color = Colors.white);

    // Heart on forehead
    final heartCx = cx + 50 * scale, heartCy = cy - 50 * scale;
    final heartPaint = Paint()..color = const Color(0xFFFF6B6B);
    canvas.drawCircle(Offset(heartCx - 8 * scale, heartCy - 5 * scale), 10 * scale, heartPaint);
    canvas.drawCircle(Offset(heartCx + 8 * scale, heartCy - 5 * scale), 10 * scale, heartPaint);
    final tri = Path()
      ..moveTo(heartCx - 18 * scale, heartCy)
      ..lineTo(heartCx + 18 * scale, heartCy)
      ..lineTo(heartCx, heartCy + 18 * scale)
      ..close();
    canvas.drawPath(tri, heartPaint);

    // Sparkles
    final sparkPaint = Paint()..color = const Color(0xFFFFF9C4);
    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      final angle = rng.nextDouble() * 6.28;
      final dist = 60 + rng.nextDouble() * 80;
      final sx = cx + cos(angle) * dist * scale;
      final sy = cy - 200 * scale + sin(angle) * dist * scale;
      final sr = 3 + rng.nextDouble() * 4;
      canvas.drawCircle(Offset(sx, sy), sr * scale, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
