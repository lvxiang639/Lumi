import 'dart:math';
import 'package:flutter/material.dart';

class ChatBgPainter extends CustomPainter {
  final Color dotColor;
  final Color? accentColor;

  ChatBgPainter({required this.dotColor, this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = Random(42); // fixed seed for consistent wallpaper

    // Draw tile-based wallpaper pattern (WhatsApp style)
    const tileSize = 64.0;
    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final offsetX = col * tileSize;
        final offsetY = row * tileSize;

        // Each tile has 2-3 small doodle elements
        _drawTile(canvas, offsetX, offsetY, tileSize, paint, rng);
      }
    }

    // Subtle dot grid overlay
    paint.color = dotColor.withValues(alpha: 0.3);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _drawTile(
      Canvas canvas, double ox, double oy, double size, Paint paint, Random rng) {
    final seed = (ox * 7919 + oy * 6271).toInt();
    final localRng = Random(seed);

    final count = localRng.nextInt(3) + 2; // 2-4 elements per tile

    for (int i = 0; i < count; i++) {
      final cx = ox + localRng.nextDouble() * size;
      final cy = oy + localRng.nextDouble() * size;
      final alpha = 0.06 + localRng.nextDouble() * 0.06;
      paint.color = dotColor.withValues(alpha: alpha);

      final shape = localRng.nextInt(5);
      final s = 2.0 + localRng.nextDouble() * 5.0;

      switch (shape) {
        case 0: // circle
          canvas.drawCircle(Offset(cx, cy), s / 2, paint);
          break;
        case 1: // rounded rect (chat bubble shape)
          canvas.drawRRect(
            RRect.fromLTRBR(
                cx - s, cy - s * 0.6, cx + s, cy + s * 0.6,
                Radius.circular(s * 0.5)),
            paint..style = PaintingStyle.stroke,
          );
          paint.style = PaintingStyle.fill;
          break;
        case 2: // small filled circle
          canvas.drawCircle(Offset(cx, cy), s * 0.4, paint);
          break;
        case 3: // arc / crescent
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, cy), width: s, height: s),
            localRng.nextDouble() * 3.14,
            3.14 + localRng.nextDouble() * 1.5,
            false,
            paint..style = PaintingStyle.stroke,
          );
          paint.style = PaintingStyle.fill;
          break;
        case 4: // tiny dot cluster
          for (int j = 0; j < 3; j++) {
            final dx = cx + (localRng.nextDouble() - 0.5) * s;
            final dy = cy + (localRng.nextDouble() - 0.5) * s;
            canvas.drawCircle(Offset(dx, dy), s * 0.25, paint);
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatBgPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor || oldDelegate.accentColor != accentColor;
}
