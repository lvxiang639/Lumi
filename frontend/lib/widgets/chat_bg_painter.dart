import 'dart:math';
import 'package:flutter/material.dart';

class ChatBgPainter extends CustomPainter {
  final Color dotColor;

  ChatBgPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final rng = Random(42); // fixed seed for consistent pattern
    const dotCount = 120;
    const maxRadius = 2.5;

    for (int i = 0; i < dotCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * maxRadius + 0.8;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChatBgPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
