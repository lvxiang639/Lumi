import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PetPosition { bottomBar, sidebar }

class PetCat extends StatefulWidget {
  final PetPosition position;
  final VoidCallback? onTap;

  const PetCat({super.key, this.position = PetPosition.bottomBar, this.onTap});

  @override
  State<PetCat> createState() => _PetCatState();
}

class _PetCatState extends State<PetCat> with TickerProviderStateMixin {
  late AnimationController _walkCtrl;
  bool _started = false;
  double _screenW = 400;
  double _walkX = 0;
  bool _movingRight = true;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _screenW = MediaQuery.of(context).size.width;
      _walkX = _screenW * 0.2;
      _startWalking();
    }
  }

  void _startWalking() {
    if (!mounted) return;
    final start = _walkX;
    final end = _movingRight ? _screenW - 40.0 : 40.0;
    final duration = ((end - start).abs() / 60 * 1000).toInt().clamp(5000, 15000);

    _walkCtrl.duration = Duration(milliseconds: duration);
    _walkCtrl.forward(from: 0).then((_) {
      if (mounted) {
        _movingRight = !_movingRight;
        _walkX = end;
        _startWalking();
      }
    });
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) return _sidebarCat();
    return _walkingCat();
  }

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: _walkCtrl,
      builder: (_, __) {
        final t = _walkCtrl.value;
        _walkX = _movingRight
            ? ui.lerpDouble(_walkX, _screenW - 40, t)!
            : ui.lerpDouble(_walkX, 40, t)!;

        return Positioned(
          left: _walkX,
          bottom: 2,
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: 64, height: 48,
              child: CustomPaint(
                size: const Size(64, 48),
                painter: _WalkingCatPainter(walkPhase: _walkCtrl.value * 3.14 * 2, movingRight: _movingRight),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sidebarCat() {
    return Positioned(
      right: 0,
      bottom: 40,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 40, height: 60,
          child: CustomPaint(
            size: const Size(40, 60),
            painter: _SidebarCatPainter(),
          ),
        ),
      ),
    );
  }
}

// ── Walking Cat Painter ──

class _WalkingCatPainter extends CustomPainter {
  final double walkPhase;
  final bool movingRight;
  _WalkingCatPainter({required this.walkPhase, required this.movingRight});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bodyPaint = Paint()..color = const Color(0xFFF5A623);
    final strokePaint = Paint()..color = const Color(0xFFE0960C)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final whitePaint = Paint()..color = Colors.white;
    final eyePaint = Paint()..color = const Color(0xFF4A3520);
    final pinkPaint = Paint()..color = const Color(0xFFFFB6C1);
    final nosePaint = Paint()..color = const Color(0xFFFF6B8A);

    canvas.save();
    if (!movingRight) { canvas.translate(w, 0); canvas.scale(-1, 1); }

    final bob = sin(walkPhase) * 2;
    // Cat positioned in lower half
    final bx = w * 0.55, by = h * 0.65 + bob;

    // ── Long curved tail ──
    final tailPath = Path();
    tailPath.moveTo(bx - 16, by - 2);
    tailPath.cubicTo(bx - 26, by - 8, bx - 30, by - 18, bx - 28, by - 22);
    tailPath.cubicTo(bx - 30, by - 20, bx - 24, by - 8, bx - 16, by - 1);
    canvas.drawPath(tailPath, bodyPaint);
    canvas.drawPath(tailPath, strokePaint);

    // ── Back legs (behind body) ──
    final backSwing = sin(walkPhase + 1.57) * 2.5;
    _drawLeg(canvas, bx - 8, by + 7 - backSwing, 12, bodyPaint, strokePaint, whitePaint);
    _drawLeg(canvas, bx + 1, by + 7 + backSwing, 11, bodyPaint, strokePaint, whitePaint);

    // ── Long slim body ──
    final bodyRect = RRect.fromLTRBR(bx - 17, by - 6, bx + 11, by + 6, const Radius.circular(6));
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, strokePaint);
    // Belly
    canvas.drawRRect(RRect.fromLTRBR(bx - 12, by - 2, bx + 7, by + 4, const Radius.circular(4)), whitePaint);

    // ── Front legs (in front of body) ──
    final frontSwing = sin(walkPhase) * 2.5;
    _drawLeg(canvas, bx + 5, by + 3 - frontSwing, 10, bodyPaint, strokePaint, whitePaint);
    _drawLeg(canvas, bx + 9, by + 3 + frontSwing, 9, bodyPaint, strokePaint, whitePaint);

    // ── Neck ──
    canvas.drawRRect(RRect.fromLTRBR(bx + 8, by - 10, bx + 16, by - 2, const Radius.circular(3)), bodyPaint);
    canvas.drawRRect(RRect.fromLTRBR(bx + 8, by - 10, bx + 16, by - 2, const Radius.circular(3)), strokePaint);

    // ── Head: small rounded diamond ──
    final headCx = bx + 18, headCy = by - 10;
    final facePath = Path();
    facePath.addPolygon([
      Offset(headCx, headCy - 7),   // top
      Offset(headCx + 7, headCy),   // right
      Offset(headCx + 4, headCy + 5), // bottom right
      Offset(headCx - 3, headCy + 5), // bottom left
      Offset(headCx - 6, headCy),   // left
    ], true);
    canvas.drawPath(facePath, bodyPaint);
    canvas.drawPath(facePath, strokePaint);

    // ── Large pointed ears ──
    final earPath = Path();
    earPath.moveTo(headCx - 3, headCy - 5);
    earPath.lineTo(headCx - 8, headCy - 15);
    earPath.lineTo(headCx + 1, headCy - 6);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, strokePaint);
    earPath.reset();
    earPath.moveTo(headCx + 2, headCy - 5);
    earPath.lineTo(headCx + 8, headCy - 13);
    earPath.lineTo(headCx + 6, headCy - 4);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, strokePaint);
    // Inner ear
    canvas.drawCircle(Offset(headCx - 4, headCy - 9), 2.2, pinkPaint);
    canvas.drawCircle(Offset(headCx + 5, headCy - 8), 2.2, pinkPaint);

    // ── Eyes: almond shaped ──
    canvas.drawOval(Rect.fromCenter(center: Offset(headCx - 1, headCy), width: 3.5, height: 3), eyePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(headCx + 4, headCy), width: 3.5, height: 3), eyePaint);
    canvas.drawCircle(Offset(headCx - 0.5, headCy - 0.8), 1, whitePaint);
    canvas.drawCircle(Offset(headCx + 4.5, headCy - 0.8), 1, whitePaint);

    // ── Nose ──
    canvas.drawCircle(Offset(headCx + 1.5, headCy + 2.5), 1.2, nosePaint);

    // ── Whiskers ──
    final whiskerPaint = Paint()..color = Colors.white..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (final side in [-1, 1]) {
      for (final dy in [-0.5, 0, 0.5]) {
        canvas.drawLine(Offset(headCx + 2, headCy + 2.5 + dy), Offset(headCx + 2 + side * 10, headCy + 1 + dy * 2), whiskerPaint);
      }
    }

    // ── Collar (stripes on body) ──
    final stripePaint = Paint()..color = const Color(0xFFE0960C)..strokeWidth = 2..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final sx = bx - 5 + i * 7;
      canvas.drawLine(Offset(sx, by - 6), Offset(sx, by + 6), stripePaint);
    }

    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double x, double y, double len, Paint fill, Paint stroke, Paint paw) {
    canvas.drawRRect(RRect.fromLTRBR(x, y, x + 2.5, y + len, const Radius.circular(1.2)), fill);
    canvas.drawRRect(RRect.fromLTRBR(x, y, x + 2.5, y + len, const Radius.circular(1.2)), stroke);
    canvas.drawCircle(Offset(x + 1.2, y + len), 2, paw);
    canvas.drawCircle(Offset(x + 1.2, y + len), 2, stroke);
  }

  @override
  bool shouldRepaint(covariant _WalkingCatPainter old) => old.walkPhase != walkPhase || old.movingRight != movingRight;
}

// ── Sidebar Peeking Cat Painter ──

class _SidebarCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bodyPaint = Paint()..color = const Color(0xFFF5A623);
    final outlinePaint = Paint()..color = const Color(0xFFD4891A)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final darkPaint = Paint()..color = const Color(0xFF8B6914);
    final pinkPaint = Paint()..color = const Color(0xFFFFB6C1);

    // Head peeking from right edge
    final headCx = w * 0.6, headCy = h * 0.4;
    canvas.drawCircle(Offset(headCx, headCy), 11, bodyPaint);
    canvas.drawCircle(Offset(headCx, headCy), 11, outlinePaint);

    // Ears
    final earPath = Path();
    earPath.moveTo(headCx - 5, headCy - 8);
    earPath.lineTo(headCx - 9, headCy - 16);
    earPath.lineTo(headCx, headCy - 8);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, outlinePaint);
    earPath.reset();
    earPath.moveTo(headCx + 2, headCy - 7);
    earPath.lineTo(headCx + 8, headCy - 14);
    earPath.lineTo(headCx + 8, headCy - 5);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, outlinePaint);

    canvas.drawCircle(Offset(headCx - 6, headCy - 10), 3, pinkPaint);
    canvas.drawCircle(Offset(headCx + 5, headCy - 9), 3, pinkPaint);

    // Eyes — wide, curious
    canvas.drawCircle(Offset(headCx - 3, headCy - 1), 2.5, darkPaint);
    canvas.drawCircle(Offset(headCx + 4, headCy - 1), 2.5, darkPaint);
    canvas.drawCircle(Offset(headCx - 2.3, headCy - 1.7), 1, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(headCx + 4.7, headCy - 1.7), 1, Paint()..color = Colors.white);

    // Nose
    canvas.drawCircle(Offset(headCx + 1, headCy + 2), 1.5, Paint()..color = const Color(0xFFFF6B8A));

    // Paws on edge
    final pawPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(headCx - 6, headCy + 12), 3.5, pawPaint);
    canvas.drawCircle(Offset(headCx + 1, headCy + 12), 3.5, pawPaint);
    canvas.drawCircle(Offset(headCx - 6, headCy + 12), 3.5, outlinePaint);
    canvas.drawCircle(Offset(headCx + 1, headCy + 12), 3.5, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _SidebarCatPainter old) => false;
}
