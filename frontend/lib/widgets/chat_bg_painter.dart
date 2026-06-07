import 'dart:math';
import 'package:flutter/material.dart';

class ChatBgPainter extends CustomPainter {
  final Color dotColor;

  ChatBgPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final rng = Random(42);

    // Draw WhatsApp-style repeating doodle wallpaper
    const tileSize = 80.0;
    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final ox = col * tileSize;
        final oy = row * tileSize;
        _drawTile(canvas, ox, oy, tileSize, paint, strokePaint);
      }
    }
  }

  void _drawTile(Canvas canvas, double ox, double oy, double size,
      Paint paint, Paint strokePaint) {
    final seed = ((ox * 7919 + oy * 6271).toInt() & 0x7FFFFFFF);
    final rng = Random(seed);

    final count = rng.nextInt(4) + 2; // 2-5 doodles per tile
    final alpha = 0.07 + rng.nextDouble() * 0.06;

    paint.color = dotColor.withValues(alpha: alpha);
    strokePaint.color = dotColor.withValues(alpha: alpha);

    for (int i = 0; i < count; i++) {
      final cx = ox + 8 + rng.nextDouble() * (size - 16);
      final cy = oy + 8 + rng.nextDouble() * (size - 16);
      final s = 3.0 + rng.nextDouble() * 6.0;
      final shape = rng.nextInt(10);

      switch (shape) {
        case 0: // Chat bubble with tail
          _drawChatBubble(canvas, cx, cy, s, strokePaint);
          break;
        case 1: // Heart
          _drawHeart(canvas, cx, cy, s, paint);
          break;
        case 2: // Star
          _drawStar(canvas, cx, cy, s, strokePaint);
          break;
        case 3: // Circle cluster
          _drawCircleCluster(canvas, cx, cy, s, paint, rng);
          break;
        case 4: // Phone handset
          _drawPhone(canvas, cx, cy, s, strokePaint);
          break;
        case 5: // Smiley face
          _drawSmiley(canvas, cx, cy, s, strokePaint);
          break;
        case 6: // Paper plane
          _drawPaperPlane(canvas, cx, cy, s, strokePaint);
          break;
        case 7: // Camera
          _drawCamera(canvas, cx, cy, s, strokePaint);
          break;
        case 8: // Music note
          _drawNote(canvas, cx, cy, s, strokePaint);
          break;
        case 9: // Sparkle
          _drawSparkle(canvas, cx, cy, s, strokePaint);
          break;
      }
    }
  }

  // --- Doodle shapes ---

  void _drawChatBubble(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final w = s * 1.3, h = s * 0.85;
    final r = s * 0.4;
    // Rounded rectangle
    path.addRRect(RRect.fromLTRBR(cx - w / 2, cy - h / 2, cx + w / 2,
        cy + h / 2, Radius.circular(r)));
    // Tail
    path.moveTo(cx - w / 2 + r, cy + h / 2);
    path.lineTo(cx - w / 2, cy + h / 2 + s * 0.5);
    path.lineTo(cx - w / 2 + r + s * 0.3, cy + h / 2);
    canvas.drawPath(path, paint);
  }

  void _drawHeart(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final r = s * 0.35;
    path.moveTo(cx, cy + s * 0.35);
    path.cubicTo(cx - s * 0.5, cy - s * 0.1, cx - s * 0.5, cy - s * 0.5,
        cx, cy - s * 0.2);
    path.cubicTo(cx + s * 0.5, cy - s * 0.5, cx + s * 0.5, cy - s * 0.1,
        cx, cy + s * 0.35);
    canvas.drawPath(path, paint);
  }

  void _drawStar(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final outerR = s * 0.5, innerR = s * 0.2;
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final angle = -3.1416 / 2 + i * 3.1416 / points;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCircleCluster(
      Canvas canvas, double cx, double cy, double s, Paint paint, Random rng) {
    for (int j = 0; j < 4; j++) {
      final dx = cx + (rng.nextDouble() - 0.5) * s * 1.2;
      final dy = cy + (rng.nextDouble() - 0.5) * s * 1.2;
      final rr = s * (0.15 + rng.nextDouble() * 0.2);
      canvas.drawCircle(Offset(dx, dy), rr, paint);
    }
  }

  void _drawPhone(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final w = s * 0.5, h = s * 0.8;
    // Handset body
    path.addRRect(RRect.fromLTRBR(
        cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2,
        Radius.circular(s * 0.2)));
    // Earpiece arc
    path.addArc(
        Rect.fromCenter(
            center: Offset(cx, cy - h * 0.2), width: w * 0.6, height: w * 0.6),
        3.14 * 1.2,
        3.14 * 0.6);
    canvas.drawPath(path, paint);
  }

  void _drawSmiley(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    // Face circle
    canvas.drawCircle(Offset(cx, cy), s * 0.45, paint);
    // Eyes (two small dots)
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(cx - s * 0.15, cy - s * 0.1), s * 0.06, paint);
    canvas.drawCircle(
        Offset(cx + s * 0.15, cy - s * 0.1), s * 0.06, paint);
    // Smile arc
    paint.style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, cy + s * 0.05),
            width: s * 0.4,
            height: s * 0.25),
        0.2,
        3.14 - 0.4,
        false,
        paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawPaperPlane(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final hw = s * 0.5;
    path.moveTo(cx - hw, cy + s * 0.4);
    path.lineTo(cx + hw * 0.3, cy - s * 0.1);
    path.lineTo(cx + hw, cy + s * 0.4);
    path.lineTo(cx, cy);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCamera(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    final w = s * 0.6, h = s * 0.45;
    path.addRRect(RRect.fromLTRBR(
        cx - w / 2, cy - h / 2 + s * 0.1,
        cx + w / 2, cy + h / 2,
        Radius.circular(s * 0.15)));
    // Lens circle
    canvas.drawCircle(Offset(cx, cy), s * 0.2, paint);
    // Flash
    canvas.drawCircle(Offset(cx + w * 0.3, cy - h * 0.15), s * 0.07, paint);
  }

  void _drawNote(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    // Note circle
    canvas.drawCircle(Offset(cx - s * 0.2, cy + s * 0.3), s * 0.2, paint);
    // Stem
    path.moveTo(cx, cy + s * 0.3);
    path.lineTo(cx, cy - s * 0.4);
    path.lineTo(cx + s * 0.35, cy - s * 0.2);
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(
      Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    const points = 4;
    final outerR = s * 0.45, innerR = s * 0.1;
    for (int i = 0; i < points * 2; i++) {
      final angle = i * 3.1416 / points;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ChatBgPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
