import 'dart:math' as math;
import 'package:flutter/material.dart';

class CharacterView extends StatefulWidget {
  final double mouthOpen;
  final String animState;

  const CharacterView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _danceAngle = 0.0;
  bool _isDancing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _controller.addListener(_onAnimTick);
  }

  void _onAnimTick() {
    if (_isDancing) {
      setState(() => _danceAngle += 0.05);
    }
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animState == 'dancing' && !_isDancing) {
      _isDancing = true;
      _danceAngle = 0.0;
    } else if (widget.animState != 'dancing' && _isDancing) {
      _isDancing = false;
      _danceAngle = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GirlPainter(
            mouthOpen: widget.mouthOpen,
            animState: widget.animState,
            animValue: _controller.value,
            danceAngle: _danceAngle,
            isDancing: _isDancing,
          ),
        );
      },
    );
  }
}

class _GirlPainter extends CustomPainter {
  final double mouthOpen;
  final String animState;
  final double animValue;
  final double danceAngle;
  final bool isDancing;

  _GirlPainter({
    required this.mouthOpen,
    required this.animState,
    required this.animValue,
    required this.danceAngle,
    required this.isDancing,
  });

  // ── Color palette ──
  static const skinColor = Color(0xFFFFF0E0);
  static const skinShadow = Color(0xFFF5D5C0);
  static const hairColor = Color(0xFF3D2B1F);
  static const hairHighlight = Color(0xFF6B4C3B);
  static const eyeColor = Color(0xFF5B6ABF);
  static const eyeDark = Color(0xFF2C3A6E);
  static const dressMain = Color(0xFFF8F0FF);
  static const dressAccent = Color(0xFFBE9FDF);
  static const dressTrim = Color(0xFF9B7EC4);
  static const ribbonColor = Color(0xFFFF7EB3);
  static const blushColor = Color(0x40FF6B8A);
  static const mouthColor = Color(0xFFF08080);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height / 2 + 30;
    final idleOffset = !isDancing ? math.sin(animValue * 2 * math.pi) * 6.0 : 0.0;
    final cy = baseY + idleOffset;

    canvas.save();
    canvas.translate(cx, cy);

    if (isDancing) {
      final s = 1.0 + math.sin(danceAngle * 3) * 0.1;
      canvas.scale(s, s);
      canvas.rotate(danceAngle);
    }

    final isTalking = animState == 'talking';

    _drawHairBack(canvas, isTalking);
    _drawBody(canvas);
    _drawArms(canvas, isTalking);
    _drawNeck(canvas);
    _drawFace(canvas);
    _drawEyes(canvas, isTalking);
    _drawEyebrows(canvas, isTalking);
    _drawNose(canvas);
    _drawMouth(canvas, isTalking);
    _drawBlush(canvas);
    _drawHairFront(canvas, isTalking);
    _drawHairOrnament(canvas);

    canvas.restore();
  }

  // ── Neck ──
  void _drawNeck(Canvas c) {
    final p = Paint()..color = skinColor;
    c.drawRect(Rect.fromLTWH(-8, -60, 16, 24), p);
    // Shadow
    final ps = Paint()..color = skinShadow;
    c.drawRect(Rect.fromLTWH(-2, -60, 4, 24), ps);
  }

  // ── Face (oval, pointed chin) ──
  void _drawFace(Canvas c) {
    final facePath = Path()
      ..moveTo(0, -110) // top center
      ..cubicTo(30, -110, 52, -90, 48, -60) // right upper
      ..cubicTo(44, -30, 28, -10, 0, -16) // right jaw to chin
      ..cubicTo(-28, -10, -44, -30, -48, -60) // left jaw
      ..cubicTo(-52, -90, -30, -110, 0, -110) // left upper
      ..close();
    final facePaint = Paint()..color = skinColor;
    c.drawPath(facePath, facePaint);
  }

  // ── Body (elegant dress) ──
  void _drawBody(Canvas c) {
    // Torso
    final torsoPath = Path()
      ..moveTo(-14, -40)
      ..quadraticBezierTo(-16, 10, -12, 50)
      ..lineTo(12, 50)
      ..quadraticBezierTo(16, 10, 14, -40)
      ..close();
    final torsoPaint = Paint()..color = dressMain;
    c.drawPath(torsoPath, torsoPaint);

    // Waist bow
    final bowP = Paint()..color = ribbonColor;
    final bx = 0.0, by = 15.0;
    c.drawOval(Rect.fromCenter(center: Offset(bx - 10, by), width: 14, height: 8), bowP);
    c.drawOval(Rect.fromCenter(center: Offset(bx + 10, by), width: 14, height: 8), bowP);
    c.drawCircle(Offset(bx, by), 4, bowP);
    // Bow tails
    final tailP = Paint()..color = ribbonColor..style = PaintingStyle.stroke..strokeWidth = 2.5;
    c.drawLine(Offset(bx - 2, by + 2), Offset(bx - 8, by + 20), tailP);
    c.drawLine(Offset(bx + 2, by + 2), Offset(bx + 8, by + 20), tailP);

    // Skirt
    final skirtPath = Path()
      ..moveTo(-12, 50)
      ..lineTo(12, 50)
      ..cubicTo(24, 55, 32, 70, 28, 85)
      ..quadraticBezierTo(0, 92, -28, 85)
      ..cubicTo(-32, 70, -24, 55, -12, 50)
      ..close();
    final skirtPaint = Paint()..color = dressMain;
    c.drawPath(skirtPath, skirtPaint);

    // Skirt trim
    final trimPaint = Paint()
      ..color = dressAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final trimPath = Path()
      ..moveTo(-14, 52)
      ..quadraticBezierTo(0, 58, 14, 52);
    c.drawPath(trimPath, trimPaint);

    // Skirt bottom ruffle line
    final rufflePath = Path()
      ..moveTo(-26, 82)
      ..quadraticBezierTo(0, 90, 26, 82);
    c.drawPath(rufflePath, Paint()..color = dressTrim..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Collar / neckline detail
    final collarPath = Path()
      ..moveTo(-10, -38)
      ..quadraticBezierTo(0, -30, 10, -38);
    c.drawPath(collarPath, Paint()..color = dressAccent..style = PaintingStyle.stroke..strokeWidth = 2);

    // Small chest bow
    c.drawCircle(const Offset(0, -32), 3, Paint()..color = ribbonColor);
  }

  // ── Arms ──
  void _drawArms(Canvas c, bool isTalking) {
    final armP = Paint()..color = skinColor..strokeWidth = 8..strokeCap = StrokeCap.round;

    if (isDancing) {
      c.drawLine(const Offset(-10, -36), const Offset(-35, -55), armP);
      c.drawLine(const Offset(10, -36), const Offset(35, -55), armP);
    } else if (isTalking) {
      final g = math.sin(animValue * 3 * math.pi) * 6;
      c.drawLine(const Offset(-10, -36), Offset(-28 + g, -10), armP);
      c.drawLine(const Offset(10, -36), Offset(28 - g, -10), armP);
    } else {
      c.drawLine(const Offset(-10, -36), const Offset(-26, 4), armP);
      c.drawLine(const Offset(10, -36), const Offset(26, 4), armP);
    }

    // Hands (simple circles)
    if (isDancing) {
      c.drawCircle(const Offset(-35, -58), 5, Paint()..color = skinColor);
      c.drawCircle(const Offset(35, -58), 5, Paint()..color = skinColor);
    }
  }

  // ── Hair (back layer) ──
  void _drawHairBack(Canvas c, bool isTalking) {
    final hp = Paint()..color = hairColor;

    // Main back hair
    final backPath = Path()
      ..moveTo(-46, -100)
      ..cubicTo(-54, -80, -52, -40, -38, 20)
      ..quadraticBezierTo(-20, 70, 0, 90)
      ..quadraticBezierTo(20, 70, 38, 20)
      ..cubicTo(52, -40, 54, -80, 46, -100)
      ..close();
    c.drawPath(backPath, hp);

    // Hair sway in talking/dancing
    double sway = 0;
    if (isTalking) sway = math.sin(animValue * 2.5 * math.pi) * 4;
    if (isDancing) sway = math.sin(danceAngle * 1.5) * 8;

    // Side strands
    final strandP = Paint()..color = hairHighlight..strokeWidth = 3..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-44, -60), Offset(-38 + sway, 10), strandP);
    c.drawLine(Offset(44, -60), Offset(38 + sway, 10), strandP);
    c.drawLine(Offset(-43, -58), Offset(-36 + sway * 0.7, 20), strandP);
    c.drawLine(Offset(43, -58), Offset(36 + sway * 0.7, 20), strandP);

    // Hair highlight streaks
    final streakP = Paint()..color = hairHighlight.withAlpha(80)..strokeWidth = 2;
    c.drawLine(Offset(-20, -95), Offset(-18 + sway, -20), streakP);
    c.drawLine(Offset(20, -95), Offset(18 + sway, -20), streakP);
  }

  // ── Hair (front layer + bangs) ──
  void _drawHairFront(Canvas c, bool isTalking) {
    final hp = Paint()..color = hairColor;

    // Long bangs sweeping to the side
    final bangsPath = Path()
      ..moveTo(-44, -102)
      ..cubicTo(-34, -78, -28, -56, -20, -50)
      ..lineTo(-8, -50)
      ..quadraticBezierTo(-2, -56, 10, -54)
      ..cubicTo(24, -56, 34, -78, 44, -102)
      ..cubicTo(30, -96, 10, -80, 0, -78)
      ..cubicTo(-10, -80, -30, -96, -44, -102)
      ..close();
    c.drawPath(bangsPath, hp);

    // Side bangs framing face
    final sideBangL = Path()
      ..moveTo(-46, -100)
      ..cubicTo(-50, -80, -46, -56, -34, -40)
      ..lineTo(-28, -44)
      ..cubicTo(-38, -54, -40, -74, -38, -96)
      ..close();
    c.drawPath(sideBangL, hp);

    final sideBangR = Path()
      ..moveTo(46, -100)
      ..cubicTo(50, -80, 46, -56, 34, -40)
      ..lineTo(28, -44)
      ..cubicTo(38, -54, 40, -74, 38, -96)
      ..close();
    c.drawPath(sideBangR, hp);

    // Ahoge (cowlick)
    final ahogePath = Path()
      ..moveTo(0, -108)
      ..quadraticBezierTo(6, -115, 12, -110)
      ..quadraticBezierTo(10, -114, 8, -108)
      ..close();
    c.drawPath(ahogePath, hp);
  }

  // ── Hair ornament (flower clip) ──
  void _drawHairOrnament(Canvas c) {
    final cx = -36.0, cy = -88.0;
    // Petals
    final petalP = Paint()..color = ribbonColor;
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final px = cx + math.cos(a) * 6;
      final py = cy + math.sin(a) * 6;
      c.drawCircle(Offset(px, py), 4.5, petalP);
    }
    // Center
    c.drawCircle(Offset(cx, cy), 3, Paint()..color = const Color(0xFFFFF176));
  }

  // ── Eyes (anime style, large and detailed) ──
  void _drawEyes(Canvas c, bool isTalking) {
    final blink = (animValue * 0.45) % 1.0;
    final isBlink = blink > 0.93;
    final blinkT = isBlink ? ((blink - 0.93) / 0.07).clamp(0.0, 1.0) : 0.0;

    for (final side in [-1, 1]) {
      final dx = 16.0 * side;
      final dy = -76.0;

      if (isBlink && blinkT > 0.8) {
        // Closed eye line
        final lp = Paint()
          ..color = eyeDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final lp2 = Path()
          ..moveTo(dx - 14, dy)
          ..quadraticBezierTo(dx, dy + 6, dx + 14, dy);
        c.drawPath(lp2, lp);
        // Eyelashes
        for (var lx = dx - 10; lx <= dx + 10; lx += 6) {
          c.drawLine(Offset(lx.toDouble(), dy), Offset(lx.toDouble(), dy + 4), lp);
        }
        continue;
      }

      final h = isBlink ? 22.0 * (1 - blinkT) : 22.0;

      // Eye white
      final whiteR = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(dx, dy), width: 26, height: h),
        const Radius.circular(10),
      );
      c.drawRRect(whiteR, Paint()..color = Colors.white);

      // Upper lash line
      final lashPath = Path()
        ..moveTo(dx - 15, dy - 3)
        ..quadraticBezierTo(dx, dy - h / 2 - 4, dx + 15, dy - 3);
      c.drawPath(lashPath, Paint()
        ..color = eyeDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);

      // Iris
      c.drawCircle(Offset(dx, dy + 1), 8, Paint()..color = eyeColor);

      // Iris gradient (top darker)
      c.drawCircle(Offset(dx, dy - 1), 6.5, Paint()..color = eyeColor.withAlpha(180));
      c.drawCircle(Offset(dx, dy + 2), 5, Paint()..color = eyeColor.withAlpha(220));

      // Pupil
      c.drawCircle(Offset(dx, dy + 1), 3.5, Paint()..color = eyeDark);

      // Highlights
      c.drawCircle(Offset(dx - 3, dy - 4), 2.8, Paint()..color = Colors.white);
      c.drawCircle(Offset(dx + 2, dy - 1), 1.5, Paint()..color = Colors.white);
    }
  }

  // ── Eyebrows ──
  void _drawEyebrows(Canvas c, bool isTalking) {
    final bp = Paint()
      ..color = hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final lift = isTalking ? -3.0 : 0.0;

    for (final side in [-1, 1]) {
      final dx = 16.0 * side;
      final dy = -98.0 + lift;
      final p = Path()
        ..moveTo(dx - 14, dy - 2)
        ..quadraticBezierTo(dx, dy - 6, dx + 14, dy - 2);
      c.drawPath(p, bp);
    }
  }

  // ── Nose ──
  void _drawNose(Canvas c) {
    // Small subtle nose
    final nosePath = Path()
      ..moveTo(0, -68)
      ..quadraticBezierTo(3, -64, 0, -62);
    c.drawPath(nosePath, Paint()..color = skinShadow..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round);
  }

  // ── Mouth ──
  void _drawMouth(Canvas c, bool isTalking) {
    final my = -54.0;

    if (isTalking && mouthOpen > 0.1) {
      final mh = (mouthOpen * 10).clamp(2.0, 10.0);
      // Open mouth
      c.drawOval(
        Rect.fromCenter(center: Offset(0, my), width: 14, height: mh),
        Paint()..color = mouthColor,
      );
      // Inner
      c.drawOval(
        Rect.fromCenter(center: Offset(0, my + 1), width: 9, height: (mh * 0.55).clamp(1.0, 5.0)),
        Paint()..color = const Color(0xFF8B2252),
      );
    } else if (isDancing) {
      // Happy smile
      final sp = Path()
        ..moveTo(-7, my)
        ..quadraticBezierTo(0, my + 6, 7, my);
      c.drawPath(sp, Paint()
        ..color = mouthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round);
    } else {
      // Gentle smile
      final sp = Path()
        ..moveTo(-5, my)
        ..quadraticBezierTo(0, my + 4, 5, my);
      c.drawPath(sp, Paint()
        ..color = mouthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round);
    }
  }

  // ── Blush ──
  void _drawBlush(Canvas c) {
    final bp = Paint()..color = blushColor;
    c.drawCircle(const Offset(-24, -62), 7, bp);
    c.drawCircle(const Offset(24, -62), 7, bp);
  }

  @override
  bool shouldRepaint(covariant _GirlPainter old) {
    return mouthOpen != old.mouthOpen ||
        animState != old.animState ||
        animValue != old.animValue ||
        danceAngle != old.danceAngle ||
        isDancing != old.isDancing;
  }
}
