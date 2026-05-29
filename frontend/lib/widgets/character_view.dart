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
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _controller.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    if (_isDancing) {
      setState(() {
        _danceAngle = (_danceAngle + 0.06) % (2 * math.pi);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animState == 'dancing' && (oldWidget.animState != 'dancing' || !_isDancing)) {
      _startDance();
    } else if (widget.animState != 'dancing' && _isDancing) {
      _stopDance();
    }
  }

  void _startDance() {
    _isDancing = true;
    _danceAngle = 0.0;
    _controller.stop();
    _controller.duration = const Duration(milliseconds: 16);
    _controller.repeat();
  }

  void _stopDance() {
    _isDancing = false;
    _danceAngle = 0.0;
    _controller.stop();
    _controller.duration = const Duration(seconds: 2);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idleOffset = !_isDancing
        ? math.sin(_controller.value * 2 * math.pi) * 8.0
        : 0.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CharacterPainter(
            mouthOpen: widget.mouthOpen,
            animState: widget.animState,
            idleOffset: idleOffset,
            danceAngle: _danceAngle,
            animValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final double mouthOpen;
  final String animState;
  final double idleOffset;
  final double danceAngle;
  final double animValue;

  _CharacterPainter({
    required this.mouthOpen,
    required this.animState,
    required this.idleOffset,
    required this.danceAngle,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + idleOffset;
    final isDancing = animState == 'dancing';
    final scale = isDancing
        ? 1.0 + math.sin(danceAngle * 3) * 0.15
        : 1.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    if (isDancing) {
      canvas.rotate(danceAngle);
    }

    final headTilt = animState == 'talking' ? math.sin(animValue * 2 * math.pi) * 0.04 : 0.0;
    if (headTilt != 0) {
      canvas.save();
      canvas.rotate(headTilt);
    }

    _drawHairBack(canvas);
    _drawBody(canvas);
    _drawArms(canvas);
    _drawHead(canvas);
    _drawHair(canvas);
    _drawHairAccessory(canvas);
    _drawEyes(canvas);
    _drawMouth(canvas);
    _drawBlush(canvas);

    if (headTilt != 0) {
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawHead(Canvas canvas) {
    final headPaint = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawCircle(const Offset(0, -30), 40, headPaint);
  }

  void _drawBody(Canvas canvas) {
    // Dress top
    final dressPaint = Paint()..color = const Color(0xFF7C6FF7);
    final bodyPath = Path()
      ..moveTo(-20, 10)
      ..quadraticBezierTo(0, 4, 20, 10)
      ..lineTo(24, 42)
      ..lineTo(-24, 42)
      ..close();
    canvas.drawPath(bodyPath, dressPaint);

    // Dress bottom / skirt
    final skirtPaint = Paint()..color = const Color(0xFF9B8FFB);
    final skirtPath = Path()
      ..moveTo(-24, 36)
      ..lineTo(24, 36)
      ..lineTo(34, 62)
      ..quadraticBezierTo(0, 72, -34, 62)
      ..close();
    canvas.drawPath(skirtPath, skirtPaint);

    // Dress collar
    final collarPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final collarPath = Path()
      ..moveTo(-10, 10)
      ..quadraticBezierTo(0, 16, 10, 10);
    canvas.drawPath(collarPath, collarPaint);

    // Neck bow
    final bowPaint = Paint()..color = const Color(0xFFE040FB);
    canvas.drawCircle(const Offset(0, 10), 3, bowPaint);
    canvas.drawCircle(const Offset(-5, 11), 2.5, bowPaint);
    canvas.drawCircle(const Offset(5, 11), 2.5, bowPaint);
  }

  void _drawArms(Canvas canvas) {
    final armPaint = Paint()
      ..color = const Color(0xFFFFE0BD)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    if (animState == 'talking') {
      // Gesturing arms when talking
      final gestureOffset = math.sin(animValue * 4 * math.pi) * 4;
      canvas.drawLine(
        const Offset(-18, 18),
        Offset(-30 + gestureOffset, 40),
        armPaint,
      );
      canvas.drawLine(
        const Offset(18, 18),
        Offset(30 - gestureOffset, 40),
        armPaint,
      );
    } else if (animState == 'dancing') {
      // Raised arms when dancing
      canvas.drawLine(const Offset(-18, 14), const Offset(-32, -5), armPaint);
      canvas.drawLine(const Offset(18, 14), const Offset(32, -5), armPaint);
    } else {
      canvas.drawLine(const Offset(-18, 18), const Offset(-30, 42), armPaint);
      canvas.drawLine(const Offset(18, 18), const Offset(30, 42), armPaint);
    }
  }

  void _drawHairBack(Canvas canvas) {
    final hairPaint = Paint()..color = const Color(0xFF4A3728);
    // Hair behind head
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -32), width: 82, height: 50),
      hairPaint,
    );
  }

  void _drawHair(Canvas canvas) {
    final hairPaint = Paint()..color = const Color(0xFF4A3728);

    // Bangs
    final bangsPath = Path()
      ..moveTo(-40, -44)
      ..quadraticBezierTo(-24, -24, 0, -40)
      ..quadraticBezierTo(24, -24, 40, -44)
      ..lineTo(40, -66)
      ..lineTo(-40, -66)
      ..close();
    canvas.drawPath(bangsPath, hairPaint);

    // Side hair strands
    final strandPath = Path()
      ..moveTo(-40, -44)
      ..quadraticBezierTo(-48, -30, -42, -10)
      ..lineTo(-38, -10)
      ..quadraticBezierTo(-42, -30, -36, -42)
      ..close();
    canvas.drawPath(strandPath, hairPaint);

    final strandPathR = Path()
      ..moveTo(40, -44)
      ..quadraticBezierTo(48, -30, 42, -10)
      ..lineTo(38, -10)
      ..quadraticBezierTo(42, -30, 36, -42)
      ..close();
    canvas.drawPath(strandPathR, hairPaint);

    // Pigtails
    final pigtailPaint = Paint()..color = const Color(0xFF5C4433);
    _drawPigtail(canvas, const Offset(-44, -24), pigtailPaint);
    _drawPigtail(canvas, const Offset(44, -24), pigtailPaint);
  }

  void _drawPigtail(Canvas canvas, Offset center, Paint paint) {
    canvas.drawCircle(center, 13, paint);
    // Pigtail ribbon
    final ribbonPaint = Paint()..color = const Color(0xFFE040FB);
    canvas.drawCircle(center + const Offset(0, 14), 3, ribbonPaint);
  }

  void _drawHairAccessory(Canvas canvas) {
    // Hair bow on top
    final bowPaint = Paint()..color = const Color(0xFFE040FB);
    final bowCenter = const Offset(0, -64);

    // Left loop
    final leftBowPath = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..quadraticBezierTo(-14, -60, -8, -68)
      ..close();
    canvas.drawPath(leftBowPath, bowPaint);

    // Right loop
    final rightBowPath = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..quadraticBezierTo(14, -60, 8, -68)
      ..close();
    canvas.drawPath(rightBowPath, bowPaint);

    // Center knot
    canvas.drawCircle(bowCenter + const Offset(0, -1), 3.5, bowPaint);

    // Bow tails
    final tailPaint = Paint()
      ..color = const Color(0xFFD500F9)
      ..strokeWidth = 2;
    canvas.drawLine(
      bowCenter,
      bowCenter + const Offset(-6, 6),
      tailPaint,
    );
    canvas.drawLine(
      bowCenter,
      bowCenter + const Offset(6, 6),
      tailPaint,
    );
  }

  void _drawEyes(Canvas canvas) {
    final blinkPhase = (animValue * 0.5) % 1.0;
    final isBlinking = blinkPhase > 0.92;

    if (isBlinking) {
      // Blink: draw eyelid lines
      final blinkPaint = Paint()
        ..color = const Color(0xFFFFE0BD)
        ..style = PaintingStyle.fill;
      final blinkProgress = (blinkPhase - 0.92) / 0.08;
      final eyelidHeight = 10.0 * (1 - blinkProgress);

      // Upper eyelids cover eyes
      canvas.drawRect(Rect.fromLTWH(-22, -44, 16, eyelidHeight), blinkPaint);
      canvas.drawRect(Rect.fromLTWH(6, -44, 16, eyelidHeight), blinkPaint);

      // Lashes
      final lashPaint = Paint()
        ..color = const Color(0xFF4A3728)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(-22, -44 + eyelidHeight), Offset(-6, -44 + eyelidHeight), lashPaint);
      canvas.drawLine(Offset(6, -44 + eyelidHeight), Offset(22, -44 + eyelidHeight), lashPaint);
    } else {
      // Eye whites
      final eyePaint = Paint()..color = Colors.white;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-14, -35), width: 16, height: 20),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(14, -35), width: 16, height: 20),
        eyePaint,
      );

      // Iris (indigo to match theme)
      final irisPaint = Paint()..color = const Color(0xFF6366F1);
      canvas.drawCircle(const Offset(-14, -34), 7, irisPaint);
      canvas.drawCircle(const Offset(14, -34), 7, irisPaint);

      // Iris gradient highlight (top half slightly lighter)
      final highlightPaint = Paint()
        ..color = const Color(0x338E99FF)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-14, -37), width: 12, height: 6),
        highlightPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(14, -37), width: 12, height: 6),
        highlightPaint,
      );

      // Pupils
      final pupilPaint = Paint()..color = Colors.black;
      canvas.drawCircle(const Offset(-14, -34), 3.5, pupilPaint);
      canvas.drawCircle(const Offset(14, -34), 3.5, pupilPaint);

      // Eye shine
      final shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(-16, -36), 2.2, shinePaint);
      canvas.drawCircle(const Offset(12, -36), 2.2, shinePaint);

      // Bottom eye highlight
      canvas.drawCircle(const Offset(-14, -31), 1.2, shinePaint);
      canvas.drawCircle(const Offset(14, -31), 1.2, shinePaint);

      // Eyebrows
      final browPaint = Paint()
        ..color = const Color(0xFF4A3728)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      if (animState == 'talking') {
        // Raised eyebrows when talking
        final browPathL = Path()
          ..moveTo(-22, -46)
          ..quadraticBezierTo(-14, -50, -6, -46);
        canvas.drawPath(browPathL, browPaint);
        final browPathR = Path()
          ..moveTo(6, -46)
          ..quadraticBezierTo(14, -50, 22, -46);
        canvas.drawPath(browPathR, browPaint);
      } else {
        final browPathL = Path()
          ..moveTo(-22, -45)
          ..quadraticBezierTo(-14, -48, -6, -45);
        canvas.drawPath(browPathL, browPaint);
        final browPathR = Path()
          ..moveTo(6, -45)
          ..quadraticBezierTo(14, -48, 22, -45);
        canvas.drawPath(browPathR, browPaint);
      }
    }
  }

  void _drawMouth(Canvas canvas) {
    final isTalking = animState == 'talking' && mouthOpen > 0.1;

    if (isTalking) {
      // Open mouth
      final mouthPaint = Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.fill;
      final mouthHeight = mouthOpen * 12;
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, -16),
          width: 16,
          height: mouthHeight.clamp(1.0, 12.0),
        ),
        mouthPaint,
      );

      // Inner mouth (darker)
      final innerPaint = Paint()..color = const Color(0xFF880E4F);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, -16),
          width: 10,
          height: (mouthHeight * 0.6).clamp(0.5, 7.0),
        ),
        innerPaint,
      );

      // Tongue hint
      final tonguePaint = Paint()..color = const Color(0xFFEF9A9A);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, -14.5),
          width: 6,
          height: 3,
        ),
        tonguePaint,
      );
    } else if (animState == 'dancing') {
      // Big happy smile when dancing
      final smilePaint = Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final smilePath = Path()
        ..moveTo(-8, -17)
        ..quadraticBezierTo(0, -10, 8, -17);
      canvas.drawPath(smilePath, smilePaint);
    } else {
      // Closed gentle smile
      final smilePaint = Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final smilePath = Path()
        ..moveTo(-6, -16)
        ..quadraticBezierTo(0, -12, 6, -16);
      canvas.drawPath(smilePath, smilePaint);
    }
  }

  void _drawBlush(Canvas canvas) {
    final blushPaint = Paint()..color = const Color(0x33FF6B8A);
    canvas.drawCircle(const Offset(-24, -22), 9, blushPaint);
    canvas.drawCircle(const Offset(24, -22), 9, blushPaint);
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) {
    return mouthOpen != oldDelegate.mouthOpen ||
        animState != oldDelegate.animState ||
        idleOffset != oldDelegate.idleOffset ||
        danceAngle != oldDelegate.danceAngle ||
        animValue != oldDelegate.animValue;
  }
}
