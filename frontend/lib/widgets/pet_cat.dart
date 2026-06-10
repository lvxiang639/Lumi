import 'dart:math';
import 'package:flutter/material.dart';

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
  late AnimationController _legCtrl;
  late AnimationController _tailCtrl;
  late AnimationController _blinkCtrl;
  bool _started = false;
  double _screenW = 400, _walkX = 0;
  bool _movingRight = true;
  int _stepCount = 0;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18));
    _legCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
    _tailCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _walkCtrl.addStatusListener((s) {
      if ((s == AnimationStatus.completed || s == AnimationStatus.dismissed) && mounted) {
        _stepCount++;
        if (_stepCount > 2 + Random().nextInt(2)) {
          _stepCount = 0;
          Future.delayed(Duration(seconds: 2 + Random().nextInt(2)), () {
            if (mounted) { _movingRight = !_movingRight; _startWalking(); }
          });
        } else {
          _movingRight = !_movingRight;
          _startWalking();
        }
      }
    });
  }

  void _startWalking() {
    if (!mounted) return;
    final end = _movingRight ? _screenW - 40.0 : 40.0;
    final dist = (end - _walkX).abs();
    _walkCtrl.duration = Duration(milliseconds: (dist / _screenW * 20000).toInt().clamp(10000, 30000));
    if (_movingRight) _walkCtrl.forward(from: _walkCtrl.value);
    else _walkCtrl.reverse(from: _walkCtrl.value);
  }

  void _onTap() {
    setState(() => _showParticles = true);
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _showParticles = false); });
    widget.onTap?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) { _started = true; _screenW = MediaQuery.of(context).size.width; _walkX = _screenW * 0.2; _startWalking(); }
  }

  @override
  void dispose() { _walkCtrl.dispose(); _legCtrl.dispose(); _tailCtrl.dispose(); _blinkCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) return _sidebarCat();
    return _walkingCat();
  }

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: Listenable.merge([_walkCtrl, _legCtrl, _tailCtrl, _blinkCtrl]),
      builder: (_, __) {
        _walkX = _movingRight ? lerpD(_walkX, _screenW - 40, _walkCtrl.value) : lerpD(_walkX, 40, _walkCtrl.value);
        final legPhase = _legCtrl.value * 2 * pi;
        final tailPhase = _tailCtrl.value * 2 * pi;
        final blink = _blinkCtrl.value;
        final bob = sin(_walkCtrl.value * pi * 6) * 2;

        return Positioned(
          left: _walkX, bottom: 2,
          child: GestureDetector(
            onTap: _onTap,
            child: Stack(clipBehavior: Clip.none, children: [
              Transform.translate(
                offset: Offset(0, bob),
                child: Transform.flip(
                  flipX: !_movingRight,
                  child: CustomPaint(
                    size: const Size(56, 50),
                    painter: _CatPainter(legPhase: legPhase, tailPhase: tailPhase, blink: blink),
                  ),
                ),
              ),
              if (_showParticles)
                ...List.generate(5, (i) {
                  final angle = -pi / 2 + (i - 2) * 0.35;
                  final dist = 18.0 + i * 7;
                  return Positioned(
                    top: 8 + sin(angle) * dist,
                    left: 24 + cos(angle) * dist,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 0.0),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -10 * v), child: child)),
                      child: Text(i.isEven ? '💕' : '✨', style: const TextStyle(fontSize: 13)),
                    ),
                  );
                }),
            ]),
          ),
        );
      },
    );
  }

  Widget _sidebarCat() => Positioned(
    right: 0, bottom: 50,
    child: GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 28, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFFFB347).withValues(alpha: 0.3), borderRadius: const BorderRadius.horizontal(right: Radius.circular(14))),
        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 14))),
      ),
    ),
  );
}

// ── Geometric Cat Painter (pure code, no SVG, clean minimal style) ──

class _CatPainter extends CustomPainter {
  final double legPhase, tailPhase, blink;
  _CatPainter({required this.legPhase, required this.tailPhase, required this.blink});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h * 0.6;
    final body = Paint()..color = const Color(0xFFFFB347);
    final stroke = Paint()..color = const Color(0xFFE8962E)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF4A3520);
    final pink = Paint()..color = const Color(0xFFF8BBD0);

    // ── Tail ──
    final tailPath = Path();
    tailPath.moveTo(cx - 12, cy + 6);
    tailPath.cubicTo(cx - 22, cy + 4 + sin(tailPhase) * 6, cx - 28, cy - 2 + sin(tailPhase) * 8, cx - 26, cy - 12 + sin(tailPhase) * 4);
    canvas.drawPath(tailPath, body..style = PaintingStyle.fill);
    canvas.drawPath(tailPath, stroke);

    // ── Back legs ──
    _leg(canvas, cx - 6, cy + 7, 10, sin(legPhase + pi) * 2.5, body, stroke, white);
    _leg(canvas, cx + 6, cy + 7, 9, sin(legPhase) * 2.5, body, stroke, white);

    // ── Body ──
    final bodyRect = RRect.fromLTRBR(cx - 14, cy - 5, cx + 14, cy + 8, const Radius.circular(10));
    canvas.drawRRect(bodyRect, body);
    canvas.drawRRect(bodyRect, stroke);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 2), width: 18, height: 10), white..color = Colors.white.withValues(alpha: 0.5));

    // ── Front legs ──
    _leg(canvas, cx - 4, cy + 6, 8, sin(legPhase + pi * 0.5) * 2.5, body, stroke, white);
    _leg(canvas, cx + 8, cy + 6, 7, sin(legPhase + pi * 1.5) * 2.5, body, stroke, white);

    // ── Head ──
    final headCy = cy - 14;
    canvas.drawCircle(Offset(cx + 4, headCy), 14, body);
    canvas.drawCircle(Offset(cx + 4, headCy), 14, stroke);

    // ── Ears ──
    _ear(canvas, cx - 2, headCy - 11, -1, body, stroke, pink);
    _ear(canvas, cx + 10, headCy - 10, 1, body, stroke, pink);

    // ── Face patch ──
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 4, headCy + 2), width: 16, height: 12), white..color = Colors.white.withValues(alpha: 0.3));

    // ── Eyes (blinking) ──
    final eyeH = 5.0 * (blink < 0.05 ? 0.2 : 1.0);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, headCy - 2), width: 4, height: eyeH), dark);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 8, headCy - 2), width: 4, height: eyeH), dark);
    canvas.drawCircle(Offset(cx - 0.5, headCy - 3), 1.2, white);
    canvas.drawCircle(Offset(cx + 7.5, headCy - 3), 1.2, white);

    // ── Blush ──
    canvas.drawCircle(Offset(cx - 2, headCy + 4), 5, pink..color = const Color(0xFFFFCDD2).withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + 10, headCy + 4), 5, pink..color = const Color(0xFFFFCDD2).withValues(alpha: 0.5));

    // ── Nose + Mouth ──
    canvas.drawCircle(Offset(cx + 4, headCy + 2), 1.2, Paint()..color = const Color(0xFFFF6B8A));
    final mouth = Path();
    mouth.moveTo(cx + 4, headCy + 3);
    mouth.lineTo(cx + 2, headCy + 5);
    mouth.moveTo(cx + 4, headCy + 3);
    mouth.lineTo(cx + 6, headCy + 5);
    canvas.drawPath(mouth, stroke..strokeWidth = 0.8);
  }

  void _leg(Canvas c, double x, double y, double h, double swing, Paint body, Paint stroke, Paint paw) {
    c.drawRRect(RRect.fromLTRBR(x, y + swing, x + 3, y + h, const Radius.circular(2)), body);
    c.drawRRect(RRect.fromLTRBR(x, y + swing, x + 3, y + h, const Radius.circular(2)), stroke);
    c.drawCircle(Offset(x + 1.5, y + h + swing * 0.3), 2.5, paw);
  }

  void _ear(Canvas c, double x, double y, int dir, Paint body, Paint stroke, Paint pink) {
    final path = Path();
    path.moveTo(x, y + 6);
    path.lineTo(x - 4 * dir, y - 8);
    path.lineTo(x + 2 * dir, y + 4);
    c.drawPath(path, body);
    c.drawPath(path, stroke);
    c.drawCircle(Offset(x - 2 * dir, y - 4), 3, pink);
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.legPhase != legPhase || old.tailPhase != tailPhase || old.blink != blink;
}

double lerpD(double a, double b, double t) => a + (b - a) * t;
