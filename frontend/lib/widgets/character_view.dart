import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Layered character view with smooth, natural-feeling animation.
///
/// Drives body breathing, mouth sync, eye blink, head sway, and state
/// transitions via multiple animation controllers — no external editor needed.
///
/// To upgrade to layered PNGs later, replace [Image.asset] with a [Stack] of
/// separately-animated images (head, body, mouth, eyes, etc.).
class CharacterView extends StatefulWidget {
  final double mouthOpen; // 0.0–1.0 from TTS energy envelope
  final String animState; // idle | talking | dancing

  const CharacterView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with TickerProviderStateMixin {
  // ---- animation controllers ----
  late final AnimationController _breathCtrl;
  late final AnimationController _headCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _blinkCtrl;

  // ---- animated values (smooth lerps) ----
  double _mouthValue = 0.0;
  double _bounceEnergy = 0.0;

  // ---- blink timer ----
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    // Slow breathing — always running
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    // Gentle head tilt (randomised phase feels organic)
    _headCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    )..repeat(reverse: true);

    // Quick bounce for talking / dancing
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Blink — 150 ms close + reopen
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scheduleBlink();
  }

  // ---- blink scheduler ----

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    // Blink every 2.5–5.5 seconds
    final delay = 2500 + math.Random().nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _blinkCtrl.forward().then((_) {
        if (mounted) _blinkCtrl.reverse();
      });
      _scheduleBlink();
    });
  }

  // ---- react to TTS mouth-open changes ----

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (old.animState != widget.animState) {
      _onStateChanged();
    }
  }

  void _onStateChanged() {
    if (widget.animState == 'talking' || widget.animState == 'dancing') {
      _bounceCtrl.repeat(reverse: true);
    } else {
      _bounceCtrl.stop();
      _bounceCtrl.animateBack(0,
          duration: const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathCtrl.dispose();
    _headCtrl.dispose();
    _bounceCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    // Smooth-lerp mouth toward target (reactive, no controller needed)
    final targetMouth = widget.mouthOpen.clamp(0.0, 1.0);
    _mouthValue += (targetMouth - _mouthValue) * 0.35;

    // Energy follows mouth for talking, higher for dancing
    final energyTarget =
        widget.animState == 'dancing' ? 1.0 : targetMouth;
    _bounceEnergy += (energyTarget - _bounceEnergy) * 0.25;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathCtrl,
        _headCtrl,
        _bounceCtrl,
        _blinkCtrl,
      ]),
      builder: (context, _) {
        final breath = _breathCtrl.value; // 0→1→0…
        final head = _headCtrl.value;
        final bounce = _bounceCtrl.isAnimating ? _bounceCtrl.value : 0.0;
        final blink = _blinkCtrl.value;

        // ---- compute transforms ----

        // Breath: smooth float up/down (sin curve)
        final breathCurve = math.sin(breath * math.pi);
        final floatY = breathCurve * 10 * (1.0 + _bounceEnergy * 0.5);

        // Head tilt: gentle left-right, more active when talking
        final tiltCurve = math.sin(head * 2 * math.pi);
        final tilt = tiltCurve * 0.04 * (1.0 + _bounceEnergy);

        // Bounce: quick up-down for talking rhythm
        final bounceCurve = math.sin(bounce * 2 * math.pi);
        final bounceY = bounceCurve * 4 * _bounceEnergy;

        // Mouth: subtle overall scale pulse (augment with mouthOpen)
        final mouthScale =
            1.0 + _mouthValue * 0.03 + _bounceEnergy * 0.01;

        // Blink: compress vertically during blink
        final blinkScaleY = blink < 0.5
            ? 1.0 - blink * 0.12 // closing
            : 0.94 + (blink - 0.5) * 0.12; // reopening

        // Dancing: extra horizontal sway
        final danceSway = widget.animState == 'dancing'
            ? math.sin(bounce * 3 * math.pi) * 0.08
            : 0.0;

        return Transform.translate(
          offset: Offset(danceSway * 30, -floatY - bounceY * 6),
          child: Transform.rotate(
            angle: tilt + danceSway,
            child: Transform.scale(
              scale: mouthScale,
              alignment: Alignment.center,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(1, 1, blinkScaleY),
                alignment: const Alignment(0, -0.5),
                child: Image.asset(
                  'assets/character.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
