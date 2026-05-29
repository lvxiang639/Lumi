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
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
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
        size: Size.infinite,
        painter: _MusePainter(
          mouthOpen: widget.mouthOpen,
          animState: widget.animState,
          t: _ctrl.value,
        ),
      ),
    );
  }
}

// ── Color palette ──
const _skinBase = Color(0xFFFFF3E6);
const _skinShd = Color(0xFFFADDC8);
const _hairBase = Color(0xFF3D2B1F);
const _hairLight = Color(0xFF604030);
const _hairGrad = Color(0xFF7B5540);
const _eyeTop = Color(0xFF4A3F8F);
const _eyeBot = Color(0xFF7B72C7);
const _eyePup = Color(0xFF1A1040);
const _dressTop = Color(0xFFFFF0F5);
const _dressBot = Color(0xFFE8D5F0);
const _dressTrim = Color(0xFFC9A0DC);
const _ribbon = Color(0xFFFF8FAB);
const _ribbonDark = Color(0xFFE0557A);
const _blush = Color(0x30FF7093);
const _mouth = Color(0xFFE87878);
const _mouthIn = Color(0xFFA03040);

class _MusePainter extends CustomPainter {
  final double mouthOpen;
  final String animState;
  final double t;

  _MusePainter({required this.mouthOpen, required this.animState, required this.t});

  bool get dancing => animState == 'dancing';
  bool get talking => animState == 'talking';

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2 + 40;
    final idle = !dancing ? math.sin(t * 2 * math.pi) * 5 : 0.0;

    c.save();
    c.translate(cx, cy + idle);

    if (dancing) {
      c.scale(1.0 + math.sin(t * 6 * math.pi) * 0.08);
      c.rotate(math.sin(t * 3 * math.pi) * 0.25);
    }

    _hairBack(c);
    _legs(c);
    _dressBack(c);
    _body(c);
    _arms(c);
    _neck(c);
    _head(c);
    _face(c);
    _eyes(c);
    _brows(c);
    _nose(c);
    _drawMouth(c);
    _drawBlush(c);
    _hairFront(c);
    _ribbon_(c);
    _hairStrands(c);

    c.restore();
  }

  // ── LEGS ──
  void _legs(Canvas c) {
    final p = Paint()..color = _skinBase;
    final skirtY = 36.0; // shorter skirt, mid-thigh
    if (dancing) {
      c.drawRRect(RRect.fromLTRBR(-2, skirtY, 6, skirtY + 44, const Radius.circular(7)), p);
      c.drawRRect(RRect.fromLTRBR(8, skirtY, 16, skirtY + 40, const Radius.circular(7)), p);
    } else {
      c.drawRRect(RRect.fromLTRBR(-10, skirtY, -2, skirtY + 50, const Radius.circular(8)), p);
      c.drawRRect(RRect.fromLTRBR(2, skirtY, 10, skirtY + 50, const Radius.circular(8)), p);
    }
    // Knee-high socks
    final sp = Paint()..color = const Color(0xFFFFFFFF);
    if (!dancing) {
      c.drawRRect(RRect.fromLTRBR(-10, skirtY + 28, -2, skirtY + 42, const Radius.circular(4)), sp);
      c.drawRRect(RRect.fromLTRBR(2, skirtY + 28, 10, skirtY + 42, const Radius.circular(4)), sp);
    }
    // Sock trim
    final st = Paint()..color = const Color(0xFFB0A0D0)..strokeWidth = 1.5;
    if (!dancing) {
      c.drawLine(Offset(-10, skirtY + 40), Offset(-2, skirtY + 40), st);
      c.drawLine(Offset(2, skirtY + 40), Offset(10, skirtY + 40), st);
    }
    // Shoes
    final sh = Paint()..color = const Color(0xFFCC8899);
    if (dancing) {
      c.drawOval(Rect.fromLTWH(-5, skirtY + 38, 14, 8), sh);
      c.drawOval(Rect.fromLTWH(5, skirtY + 34, 14, 8), sh);
    } else {
      c.drawOval(Rect.fromLTWH(-12, skirtY + 44, 14, 8), sh);
      c.drawOval(Rect.fromLTWH(-2, skirtY + 44, 14, 8), sh);
    }
  }

  // ── DRESS BACK (short skirt) ──
  void _dressBack(Canvas c) {
    // Skirt - short, pleated style
    final p = Paint()..color = _dressBot;
    final path = Path()
      ..moveTo(-22, 14)
      ..cubicTo(-30, 28, -26, 38, -18, 38)
      ..lineTo(18, 38)
      ..cubicTo(26, 38, 30, 28, 22, 14)
      ..close();
    c.drawPath(path, p);
    // Skirt hem
    c.drawPath(
      Path()..moveTo(-20, 36)..quadraticBezierTo(0, 42, 20, 36),
      Paint()..color = _dressTrim..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    // Pleat lines
    final fp = Paint()..color = _dressTrim..style = PaintingStyle.stroke..strokeWidth = 1;
    c.drawLine(const Offset(-8, 18), const Offset(-9, 37), fp);
    c.drawLine(const Offset(0, 16), const Offset(0, 38), fp);
    c.drawLine(const Offset(8, 18), const Offset(9, 37), fp);
  }

  // ── BODY ──
  void _body(Canvas c) {
    // Torso
    final torso = Path()
      ..moveTo(-14, -8)
      ..quadraticBezierTo(-18, 10, -14, 28)
      ..lineTo(14, 28)
      ..quadraticBezierTo(18, 10, 14, -8)
      ..close();
    c.drawPath(torso, Paint()..color = _dressTop);

    // Neckline
    final nl = Path()
      ..moveTo(-12, -6)
      ..quadraticBezierTo(0, 4, 12, -6);
    c.drawPath(nl, Paint()..color = _dressTrim..style = PaintingStyle.stroke..strokeWidth = 1.8);

    // Waist bow
    final bx = 0.0, by = 26.0;
    c.drawOval(Rect.fromCenter(center: Offset(bx - 10, by - 1), width: 13, height: 7), Paint()..color = _ribbon);
    c.drawOval(Rect.fromCenter(center: Offset(bx + 10, by - 1), width: 13, height: 7), Paint()..color = _ribbon);
    c.drawCircle(Offset(bx, by), 3.5, Paint()..color = _ribbonDark);
    // Bow tails
    c.drawLine(Offset(bx - 2, by + 3), Offset(bx - 8, by + 22), Paint()..color = _ribbonDark..strokeWidth = 2..strokeCap = StrokeCap.round);
    c.drawLine(Offset(bx + 2, by + 3), Offset(bx + 8, by + 22), Paint()..color = _ribbonDark..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  // ── ARMS ──
  void _arms(Canvas c) {
    final ap = Paint()..color = _skinBase..strokeWidth = 7..strokeCap = StrokeCap.round;
    if (dancing) {
      c.drawLine(const Offset(-12, -4), Offset(-40, -30), ap);
      c.drawLine(const Offset(12, -4), Offset(40, -30), ap);
      c.drawCircle(const Offset(-40, -32), 4.5, Paint()..color = _skinBase);
      c.drawCircle(const Offset(40, -32), 4.5, Paint()..color = _skinBase);
    } else if (talking) {
      final g = math.sin(t * 3.5 * math.pi) * 5;
      c.drawLine(const Offset(-12, -4), Offset(-26 + g, -12), ap);
      c.drawLine(const Offset(12, -4), Offset(26 - g, -12), ap);
    } else {
      c.drawLine(const Offset(-12, -4), const Offset(-22, 18), ap);
      c.drawLine(const Offset(12, -4), const Offset(22, 18), ap);
    }
  }

  // ── NECK ──
  void _neck(Canvas c) {
    c.drawRect(Rect.fromLTWH(-6, -50, 12, 18), Paint()..color = _skinBase);
    c.drawRect(Rect.fromLTWH(-2, -50, 4, 18), Paint()..color = _skinShd);
  }

  // ── HEAD ──
  void _head(Canvas c) {
    // Oval head with slight chin
    final path = Path()
      ..moveTo(0, -112)
      ..cubicTo(28, -112, 48, -88, 44, -62)
      ..cubicTo(40, -38, 24, -20, 0, -26)
      ..cubicTo(-24, -20, -40, -38, -44, -62)
      ..cubicTo(-48, -88, -28, -112, 0, -112);
    c.drawPath(path, Paint()..color = _skinBase);

    // Shadow under chin
    final shd = Path()
      ..moveTo(-16, -24)
      ..quadraticBezierTo(0, -18, 16, -24)
      ..lineTo(0, -30)
      ..close();
    c.drawPath(shd, Paint()..color = _skinShd);
  }

  // ── FACE CONTOUR ──
  void _face(Canvas c) {
    // Subtle nose shadow
    c.drawCircle(const Offset(0, -68), 2.5, Paint()..color = _skinShd);
  }

  // ── EYES ──
  void _eyes(Canvas c) {
    final blink = (t * 0.4) % 1.0;
    final blinking = blink > 0.93;
    final bt = blinking ? ((blink - 0.93) / 0.07).clamp(0.0, 1.0) : 0.0;

    for (final side in [-1, 1]) {
      final dx = 15.0 * side;
      final dy = -80.0;
      final eyeH = blinking ? (20.0 * (1 - bt)).clamp(1.0, 20.0) : 20.0;

      if (blinking && bt > 0.85) {
        // Closed eye
        c.drawPath(
          Path()..moveTo(dx - 12, dy)..quadraticBezierTo(dx, dy + 5, dx + 12, dy),
          Paint()..color = _eyePup..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round,
        );
        // Lashes
        for (var lx = dx - 9.0; lx <= dx + 9; lx += 5) {
          c.drawLine(Offset(lx, dy), Offset(lx, dy + 4), Paint()..color = _eyePup..strokeWidth = 1.5);
        }
        continue;
      }

      // Eye white
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(dx, dy), width: 24, height: eyeH), const Radius.circular(10)),
        Paint()..color = Colors.white,
      );

      // Upper eyelid shadow
      c.drawPath(
        Path()..addOval(Rect.fromCenter(center: Offset(dx, dy - 2), width: 25, height: eyeH + 2)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x18FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromCenter(center: Offset(dx, dy), width: 28, height: eyeH + 8)),
      );

      // Iris
      c.drawCircle(Offset(dx, dy + 1), 7.5, Paint()..color = _eyeTop);
      c.drawCircle(Offset(dx, dy - 1), 6, Paint()..color = _eyeBot);
      // Pupil
      c.drawCircle(Offset(dx, dy + 1), 3.2, Paint()..color = _eyePup);
      // Highlights
      c.drawCircle(Offset(dx - 2.5, dy - 3.5), 2.5, Paint()..color = Colors.white);
      c.drawCircle(Offset(dx + 2, dy - 0.5), 1.2, Paint()..color = Colors.white);

      // Upper lash line
      c.drawPath(
        Path()..moveTo(dx - 14, dy - 2)..quadraticBezierTo(dx, dy - eyeH / 2 - 4, dx + 14, dy - 2),
        Paint()..color = _eyePup..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round,
      );
      // Lower lash
      c.drawPath(
        Path()..moveTo(dx - 10, dy + eyeH / 2 - 1)..quadraticBezierTo(dx, dy + eyeH / 2 + 2, dx + 10, dy + eyeH / 2 - 1),
        Paint()..color = _eyePup.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.2,
      );
    }
  }

  // ── EYEBROWS ──
  void _brows(Canvas c) {
    final lift = talking ? -2.5 : 0.0;
    for (final side in [-1, 1]) {
      final dx = 15.0 * side;
      c.drawPath(
        Path()..moveTo(dx - 12, -102 + lift)..quadraticBezierTo(dx, -107 + lift, dx + 12, -102 + lift),
        Paint()..color = _hairBase..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── NOSE ──
  void _nose(Canvas c) {
    c.drawPath(
      Path()..moveTo(0, -72)..quadraticBezierTo(2.5, -68, 0, -66),
      Paint()..color = _skinShd..style = PaintingStyle.stroke..strokeWidth = 1..strokeCap = StrokeCap.round,
    );
  }

  // ── MOUTH ──
  void _drawMouth(Canvas c) {
    if (talking && mouthOpen > 0.1) {
      final h = (mouthOpen * 9).clamp(2.0, 9.0);
      c.drawOval(Rect.fromCenter(center: const Offset(0, -58), width: 12, height: h), Paint()..color = _mouth);
      c.drawOval(Rect.fromCenter(center: const Offset(0, -57), width: 7, height: (h * 0.5).clamp(1.0, 4.5)), Paint()..color = _mouthIn);
    } else if (dancing) {
      c.drawPath(
        Path()..moveTo(-6, -58)..quadraticBezierTo(0, -51, 6, -58),
        Paint()..color = _mouth..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round,
      );
    } else {
      c.drawPath(
        Path()..moveTo(-4, -58)..quadraticBezierTo(0, -54, 4, -58),
        Paint()..color = _mouth..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── BLUSH ──
  void _drawBlush(Canvas c) {
    c.drawCircle(const Offset(-22, -66), 6, Paint()..color = _blush);
    c.drawCircle(const Offset(22, -66), 6, Paint()..color = _blush);
  }

  // ── HAIR BACK (behind head, narrow, neck visible) ──
  void _hairBack(Canvas c) {
    final p = Paint()..color = _hairBase;
    // Hair stays on top/back of head, NOT covering neck area
    final path = Path()
      ..moveTo(-40, -106)
      ..cubicTo(-44, -74, -40, -40, -30, -14)
      ..cubicTo(-20, 4, -8, 16, 0, 18)
      ..cubicTo(8, 16, 20, 4, 30, -14)
      ..cubicTo(40, -40, 44, -74, 40, -106);
    c.drawPath(path, p);

    // Gradient
    final gp = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_hairGrad, _hairBase],
      ).createShader(const Rect.fromLTWH(-50, -115, 100, 140));
    c.drawPath(path, gp..blendMode = BlendMode.srcATop);
  }

  // ── HAIR FRONT (anime-style: few thin strands, forehead visible) ──
  void _hairFront(Canvas c) {
    final idleW = math.sin(t * 1.5 * math.pi) * 1.0;

    // Thin wispy strands across forehead - spaced apart, see-through
    final wispP = Paint()..color = _hairLight.withAlpha(160)..strokeWidth = 1.0..strokeCap = StrokeCap.round;

    // Just 3-4 thin strands across the forehead, not a solid block
    c.drawPath(
      Path()..moveTo(-36, -96)..quadraticBezierTo(-24 + idleW, -84, -12, -76),
      wispP,
    );
    c.drawPath(
      Path()..moveTo(-38, -92)..quadraticBezierTo(-24 + idleW * 0.7, -80, -8, -74),
      Paint()..color = _hairGrad..strokeWidth = 1.0..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()..moveTo(36, -96)..quadraticBezierTo(24 - idleW, -84, 12, -76),
      wispP,
    );
    c.drawPath(
      Path()..moveTo(38, -92)..quadraticBezierTo(24 - idleW * 0.7, -80, 8, -74),
      Paint()..color = _hairGrad..strokeWidth = 1.0..strokeCap = StrokeCap.round,
    );

    // Center part visible - M-shape hairline
    c.drawPath(
      Path()..moveTo(-4, -72)..quadraticBezierTo(0, -70, 4, -72),
      Paint()..color = _hairGrad..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );

    // Hair tufts above ears (narrow, displaced to the side)
    final tuftP = Paint()..color = _hairBase..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()..moveTo(-44, -90)..quadraticBezierTo(-46, -70, -40, -50)..quadraticBezierTo(-36, -44, -30, -48),
      tuftP,
    );
    c.drawPath(
      Path()..moveTo(44, -90)..quadraticBezierTo(46, -70, 40, -50)..quadraticBezierTo(36, -44, 30, -48),
      tuftP,
    );
  }

  // ── HAIR STRANDS (anime-style: thin, spaced apart, behind ears, neck clear) ──
  void _hairStrands(Canvas c) {
    final idleWave = math.sin(t * 1.7 * math.pi) * 0.8;
    double sway;
    if (talking) {
      sway = math.sin(t * 3.5 * math.pi) * 2;
    } else if (dancing) {
      sway = math.sin(t * 2.5 * math.pi) * 3;
    } else {
      sway = idleWave;
    }

    // Very thin strands with clear gaps between them
    final lightP = Paint()..color = _hairLight.withAlpha(180)..strokeWidth = 0.8..strokeCap = StrokeCap.round;
    final midP = Paint()..color = _hairGrad.withAlpha(200)..strokeWidth = 1.0..strokeCap = StrokeCap.round;

    // LEFT side — strands behind ear area, neck visible between them
    _strand(c, Offset(-40, -80), Offset(-42 + sway, -52), Offset(-38 + sway, -16), lightP);   // outer
    // gap (neck visible here)
    _strand(c, Offset(-36, -72), Offset(-34 + sway * 0.6, -46), Offset(-30, -8), midP);        // inner (gap from outer)

    // RIGHT side
    _strand(c, Offset(40, -80), Offset(42 - sway, -52), Offset(38 - sway, -16), lightP);
    // gap
    _strand(c, Offset(36, -72), Offset(34 - sway * 0.6, -46), Offset(30, -8), midP);

    // Ahoge
    c.drawPath(
      Path()..moveTo(-2, -109)..quadraticBezierTo(1, -115, 4, -110)..quadraticBezierTo(3, -113, 2, -108),
      Paint()..color = _hairBase..strokeWidth = 1..style = PaintingStyle.fill,
    );
  }

  void _strand(Canvas c, Offset from, Offset cp, Offset to, Paint p) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(cp.dx, cp.dy, to.dx, to.dy);
    c.drawPath(path, p);
  }

  // ── RIBBON ──
  void _ribbon_(Canvas c) {
    final cx = -34.0, cy = -90.0;
    final rp = Paint()..color = _ribbon;
    // Left loop
    c.drawPath(Path()..moveTo(cx, cy)..cubicTo(cx - 14, cy - 10, cx - 12, cy + 10, cx, cy), rp);
    // Right loop
    c.drawPath(Path()..moveTo(cx, cy)..cubicTo(cx + 14, cy - 10, cx + 12, cy + 10, cx, cy), rp);
    // Center
    c.drawCircle(Offset(cx, cy), 3, Paint()..color = _ribbonDark);
    // Tails
    c.drawLine(Offset(cx - 1, cy + 2), Offset(cx - 5, cy + 16), Paint()..color = _ribbonDark..strokeWidth = 2);
    c.drawLine(Offset(cx + 1, cy + 2), Offset(cx + 5, cy + 16), Paint()..color = _ribbonDark..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _MusePainter o) =>
      mouthOpen != o.mouthOpen || animState != o.animState || t != o.t;
}
