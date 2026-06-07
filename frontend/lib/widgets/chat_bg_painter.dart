import 'dart:math';
import 'package:flutter/material.dart';

class ChatBgPainter extends CustomPainter {
  final Color dotColor;

  ChatBgPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const tileSize = 96.0;
    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        _drawTile(canvas, col * tileSize, row * tileSize, tileSize,
            fillPaint, strokePaint);
      }
    }
  }

  void _drawTile(Canvas canvas, double ox, double oy, double size,
      Paint fill, Paint stroke) {
    final seed = ((ox * 7919 + oy * 6271).toInt() & 0x7FFFFFFF);
    final rng = Random(seed);

    final alpha = 0.14 + rng.nextDouble() * 0.08;
    fill.color = dotColor.withValues(alpha: alpha);
    stroke.color = dotColor.withValues(alpha: alpha);

    final count = rng.nextInt(2) + 2; // 2-3 doodles per tile

    for (int i = 0; i < count; i++) {
      final cx = ox + 10 + rng.nextDouble() * (size - 20);
      final cy = oy + 10 + rng.nextDouble() * (size - 20);
      final s = 12.0 + rng.nextDouble() * 20.0; // scale (4x original)
      final kind = rng.nextInt(14);

      switch (kind) {
        case 0: _cat(canvas, cx, cy, s, stroke); break;
        case 1: _dog(canvas, cx, cy, s, stroke); break;
        case 2: _bird(canvas, cx, cy, s, stroke); break;
        case 3: _fish(canvas, cx, cy, s, stroke); break;
        case 4: _bottle(canvas, cx, cy, s, stroke); break;
        case 5: _cup(canvas, cx, cy, s, stroke); break;
        case 6: _heart(canvas, cx, cy, s, fill); break;
        case 7: _star(canvas, cx, cy, s, stroke); break;
        case 8: _flower(canvas, cx, cy, s, stroke); break;
        case 9: _leaf(canvas, cx, cy, s, stroke); break;
        case 10: _jar(canvas, cx, cy, s, stroke); break;
        case 11: _moon(canvas, cx, cy, s, stroke); break;
        case 12: _book(canvas, cx, cy, s, stroke); break;
        case 13: _key(canvas, cx, cy, s, stroke); break;
      }
    }
  }

  // ── Animals ──

  void _cat(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // Head — round
    path.addOval(Rect.fromCenter(center: Offset(cx, cy - s * 0.15), width: s * 0.7, height: s * 0.65));
    // Ears — two triangles
    path.moveTo(cx - s * 0.25, cy - s * 0.35);
    path.lineTo(cx - s * 0.4, cy - s * 0.65);
    path.lineTo(cx - s * 0.1, cy - s * 0.4);
    path.moveTo(cx + s * 0.25, cy - s * 0.35);
    path.lineTo(cx + s * 0.4, cy - s * 0.65);
    path.lineTo(cx + s * 0.1, cy - s * 0.4);
    // Body
    path.addOval(Rect.fromCenter(center: Offset(cx, cy + s * 0.3), width: s * 0.55, height: s * 0.4));
    // Tail
    path.moveTo(cx + s * 0.15, cy + s * 0.35);
    path.quadraticBezierTo(cx + s * 0.5, cy + s * 0.15, cx + s * 0.25, cy - s * 0.1);
    canvas.drawPath(path, p);
  }

  void _dog(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // Head
    path.addOval(Rect.fromCenter(center: Offset(cx, cy - s * 0.2), width: s * 0.65, height: s * 0.6));
    // Floppy ears
    path.addOval(Rect.fromCenter(center: Offset(cx - s * 0.35, cy - s * 0.15), width: s * 0.2, height: s * 0.45));
    path.addOval(Rect.fromCenter(center: Offset(cx + s * 0.35, cy - s * 0.15), width: s * 0.2, height: s * 0.45));
    // Body
    path.addOval(Rect.fromCenter(center: Offset(cx, cy + s * 0.3), width: s * 0.5, height: s * 0.35));
    // Short tail
    path.moveTo(cx + s * 0.15, cy + s * 0.3);
    path.quadraticBezierTo(cx + s * 0.45, cy + s * 0.0, cx + s * 0.35, cy - s * 0.15);
    canvas.drawPath(path, p);
  }

  void _bird(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // Body
    path.addOval(Rect.fromCenter(center: Offset(cx - s * 0.05, cy + s * 0.05), width: s * 0.55, height: s * 0.45));
    // Head
    path.addOval(Rect.fromCenter(center: Offset(cx + s * 0.2, cy - s * 0.15), width: s * 0.3, height: s * 0.3));
    // Beak
    path.moveTo(cx + s * 0.35, cy - s * 0.18);
    path.lineTo(cx + s * 0.55, cy - s * 0.15);
    path.lineTo(cx + s * 0.35, cy - s * 0.1);
    // Wing
    path.moveTo(cx - s * 0.1, cy - s * 0.05);
    path.quadraticBezierTo(cx + s * 0.0, cy - s * 0.4, cx - s * 0.2, cy - s * 0.35);
    canvas.drawPath(path, p);
  }

  void _fish(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // Body — oval
    path.addOval(Rect.fromCenter(center: Offset(cx, cy), width: s * 0.75, height: s * 0.4));
    // Tail
    path.moveTo(cx - s * 0.35, cy);
    path.lineTo(cx - s * 0.6, cy - s * 0.3);
    path.lineTo(cx - s * 0.6, cy + s * 0.3);
    path.close();
    // Eye
    canvas.drawCircle(Offset(cx + s * 0.2, cy - s * 0.05), s * 0.06, p);
  }

  // ── Containers (瓶瓶罐罐) ──

  void _bottle(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    final w = s * 0.25, h = s * 0.5;
    // Neck
    path.addRect(Rect.fromCenter(center: Offset(cx, cy - h * 0.6), width: w * 0.5, height: h * 0.35));
    // Body — rounded rectangle
    path.addRRect(RRect.fromLTRBR(
        cx - w, cy - h * 0.2, cx + w, cy + h,
        Radius.circular(s * 0.15)));
    canvas.drawPath(path, p);
  }

  void _cup(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    final w = s * 0.3, h = s * 0.45;
    // Cup body
    path.addRRect(RRect.fromLTRBR(
        cx - w, cy - h * 0.1, cx + w, cy + h,
        Radius.circular(s * 0.1)));
    // Handle
    path.addArc(
        Rect.fromCenter(center: Offset(cx + w * 0.8, cy + h * 0.1), width: w * 0.7, height: h * 0.6),
        4.0, 4.2);
    canvas.drawPath(path, p);
  }

  void _jar(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    final w = s * 0.28;
    // Lid
    path.addRRect(RRect.fromLTRBR(
        cx - w * 0.7, cy - s * 0.5, cx + w * 0.7, cy - s * 0.3,
        Radius.circular(s * 0.06)));
    // Body
    path.addRRect(RRect.fromLTRBR(
        cx - w, cy - s * 0.3, cx + w, cy + s * 0.45,
        Radius.circular(s * 0.12)));
    // Label line
    path.addRect(Rect.fromCenter(center: Offset(cx, cy + s * 0.05), width: w * 1.2, height: s * 0.04));
    canvas.drawPath(path, p);
  }

  // ── Nature ──

  void _heart(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    path.moveTo(cx, cy + s * 0.35);
    path.cubicTo(cx - s * 0.5, cy - s * 0.1, cx - s * 0.5, cy - s * 0.5, cx, cy - s * 0.2);
    path.cubicTo(cx + s * 0.5, cy - s * 0.5, cx + s * 0.5, cy - s * 0.1, cx, cy + s * 0.35);
    canvas.drawPath(path, p);
  }

  void _star(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    final outerR = s * 0.45, innerR = s * 0.18;
    for (int i = 0; i < 10; i++) {
      final angle = -1.5708 + i * 0.31416;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _flower(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // 5 petals
    for (int i = 0; i < 5; i++) {
      final angle = i * 1.25664; // 2π/5
      final px = cx + cos(angle) * s * 0.22;
      final py = cy + sin(angle) * s * 0.22;
      path.addOval(Rect.fromCenter(center: Offset(px, py), width: s * 0.28, height: s * 0.22));
    }
    // Center
    canvas.drawCircle(Offset(cx, cy), s * 0.1, p);
    canvas.drawPath(path, p);
  }

  void _leaf(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    path.moveTo(cx, cy - s * 0.45);
    path.quadraticBezierTo(cx + s * 0.35, cy - s * 0.1, cx, cy + s * 0.4);
    path.quadraticBezierTo(cx - s * 0.15, cy + s * 0.1, cx, cy - s * 0.45);
    // Stem
    path.moveTo(cx, cy + s * 0.35);
    path.lineTo(cx, cy + s * 0.5);
    canvas.drawPath(path, p);
  }

  void _moon(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    path.addOval(Rect.fromCenter(center: Offset(cx, cy), width: s * 0.55, height: s * 0.55));
    // Cutout for crescent
    path.addOval(Rect.fromCenter(center: Offset(cx + s * 0.18, cy - s * 0.05), width: s * 0.45, height: s * 0.5));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, p);
  }

  // ── Objects ──

  void _book(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    final w = s * 0.3, h = s * 0.4;
    // Left page
    path.addRRect(RRect.fromLTRBR(cx - w, cy - h, cx, cy + h, Radius.circular(s * 0.04)));
    // Right page
    path.addRRect(RRect.fromLTRBR(cx, cy - h, cx + w, cy + h, Radius.circular(s * 0.04)));
    // Spine line
    path.moveTo(cx, cy - h);
    path.lineTo(cx, cy + h);
    canvas.drawPath(path, p);
  }

  void _key(Canvas canvas, double cx, double cy, double s, Paint p) {
    final path = Path();
    // Head — circle
    path.addOval(Rect.fromCenter(center: Offset(cx - s * 0.25, cy), width: s * 0.3, height: s * 0.3));
    // Shaft
    path.addRect(Rect.fromCenter(center: Offset(cx + s * 0.12, cy), width: s * 0.4, height: s * 0.08));
    // Teeth
    path.addRect(Rect.fromCenter(center: Offset(cx + s * 0.3, cy + s * 0.1), width: s * 0.06, height: s * 0.15));
    path.addRect(Rect.fromCenter(center: Offset(cx + s * 0.2, cy + s * 0.1), width: s * 0.06, height: s * 0.12));
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant ChatBgPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
