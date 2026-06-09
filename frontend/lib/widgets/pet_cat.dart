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
    final duration = ((end - start).abs() / 80 * 1000).toInt().clamp(2000, 8000);

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
              width: 50, height: 50,
              child: CustomPaint(
                size: const Size(50, 50),
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
    final cx = w / 2, cy = h * 0.55;
    final bodyPaint = Paint()..color = const Color(0xFFF5A623);
    final outlinePaint = Paint()..color = const Color(0xFFD4891A)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final whitePaint = Paint()..color = Colors.white;
    final darkPaint = Paint()..color = const Color(0xFF8B6914);

    canvas.save();
    if (!movingRight) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    // Body bob
    final bob = sin(walkPhase) * 2.5;

    // Tail
    final tailPath = Path();
    tailPath.moveTo(cx - 9, cy - 6 + bob);
    tailPath.quadraticBezierTo(cx - 20, cy - 16 + bob, cx - 22, cy - 18 + bob * 0.5);
    tailPath.quadraticBezierTo(cx - 18, cy - 10 + bob, cx - 10, cy - 4 + bob);
    canvas.drawPath(tailPath, bodyPaint);
    canvas.drawPath(tailPath, outlinePaint);

    // Body — oval
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + bob), width: 26, height: 18), bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + bob), width: 26, height: 18), outlinePaint);

    // Belly white patch
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 3 + bob), width: 14, height: 10), whitePaint);

    // Head
    final headCy = cy - 10 + bob;
    canvas.drawCircle(Offset(cx + 2, headCy), 10, bodyPaint);
    canvas.drawCircle(Offset(cx + 2, headCy), 10, outlinePaint);

    // Ears
    final earPath = Path();
    earPath.moveTo(cx - 1, headCy - 8);
    earPath.lineTo(cx - 5, headCy - 15);
    earPath.lineTo(cx + 3, headCy - 8);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, outlinePaint);
    earPath.reset();
    earPath.moveTo(cx + 5, headCy - 7);
    earPath.lineTo(cx + 10, headCy - 13);
    earPath.lineTo(cx + 9, headCy - 5);
    canvas.drawPath(earPath, bodyPaint);
    canvas.drawPath(earPath, outlinePaint);

    // Inner ear pink
    final pinkPaint = Paint()..color = const Color(0xFFFFB6C1);
    canvas.drawCircle(Offset(cx - 2, headCy - 10), 3, pinkPaint);
    canvas.drawCircle(Offset(cx + 7, headCy - 8), 3, pinkPaint);

    // Eyes
    canvas.drawCircle(Offset(cx, headCy - 2), 2, darkPaint);
    canvas.drawCircle(Offset(cx + 5, headCy - 2), 2, darkPaint);
    // Eye shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx + 0.5, headCy - 2.5), 0.8, shinePaint);
    canvas.drawCircle(Offset(cx + 5.5, headCy - 2.5), 0.8, shinePaint);

    // Nose
    canvas.drawCircle(Offset(cx + 3, headCy + 1), 1.5, Paint()..color = const Color(0xFFFF6B8A));

    // Mouth
    final mouthPath = Path();
    mouthPath.moveTo(cx + 3, headCy + 2);
    mouthPath.lineTo(cx + 1, headCy + 4);
    mouthPath.moveTo(cx + 3, headCy + 2);
    mouthPath.lineTo(cx + 5, headCy + 4);
    canvas.drawPath(mouthPath, outlinePaint..strokeWidth = 0.6);

    // Front legs — alternating
    final frontLegSwing = sin(walkPhase) * 3;
    canvas.drawRRect(RRect.fromLTRBR(cx - 4, cy + 8 + bob - frontLegSwing, cx - 1, cy + 18 + bob, Radius.circular(2)), bodyPaint);
    canvas.drawRRect(RRect.fromLTRBR(cx - 4, cy + 8 + bob - frontLegSwing, cx - 1, cy + 18 + bob, Radius.circular(2)), outlinePaint);
    canvas.drawRRect(RRect.fromLTRBR(cx + 3, cy + 8 + bob + frontLegSwing, cx + 6, cy + 17 + bob, Radius.circular(2)), bodyPaint);
    canvas.drawRRect(RRect.fromLTRBR(cx + 3, cy + 8 + bob + frontLegSwing, cx + 6, cy + 17 + bob, Radius.circular(2)), outlinePaint);

    // Back legs
    final backLegSwing = sin(walkPhase + 1.57) * 3;
    canvas.drawRRect(RRect.fromLTRBR(cx - 8, cy + 8 + bob - backLegSwing, cx - 5, cy + 17 + bob, Radius.circular(2)), bodyPaint);
    canvas.drawRRect(RRect.fromLTRBR(cx - 8, cy + 8 + bob - backLegSwing, cx - 5, cy + 17 + bob, Radius.circular(2)), outlinePaint);
    canvas.drawRRect(RRect.fromLTRBR(cx - 1, cy + 8 + bob + backLegSwing, cx + 2, cy + 16 + bob, Radius.circular(2)), bodyPaint);
    canvas.drawRRect(RRect.fromLTRBR(cx - 1, cy + 8 + bob + backLegSwing, cx + 2, cy + 16 + bob, Radius.circular(2)), outlinePaint);

    // Paws
    canvas.drawCircle(Offset(cx - 2.5, cy + 18 + bob - frontLegSwing), 2, whitePaint);
    canvas.drawCircle(Offset(cx + 4.5, cy + 17 + bob + frontLegSwing), 2, whitePaint);
    canvas.drawCircle(Offset(cx - 6.5, cy + 17 + bob - backLegSwing), 2, whitePaint);
    canvas.drawCircle(Offset(cx + 0.5, cy + 16 + bob + backLegSwing), 2, whitePaint);

    canvas.restore();
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
