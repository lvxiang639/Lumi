import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Character view with smooth animation, backdrop, and programmatic mouth sync.
///
/// Works with a single transparent PNG — no layered images needed.
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
  late final AnimationController _breathCtrl;
  late final AnimationController _headCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _particleCtrl;

  double _mouthValue = 0.0;
  double _bounceEnergy = 0.0;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _headCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = 2500 + math.Random().nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _blinkCtrl.forward().then((_) {
        if (mounted) _blinkCtrl.reverse();
      });
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (old.animState != widget.animState) _onStateChanged();
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
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetMouth = widget.mouthOpen.clamp(0.0, 1.0);
    _mouthValue += (targetMouth - _mouthValue) * 0.35;
    final energyTarget =
        widget.animState == 'dancing' ? 1.0 : targetMouth;
    _bounceEnergy += (energyTarget - _bounceEnergy) * 0.25;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathCtrl,
        _headCtrl,
        _bounceCtrl,
        _blinkCtrl,
        _particleCtrl,
      ]),
      builder: (context, _) {
        final breath = _breathCtrl.value;
        final head = _headCtrl.value;
        final bounce = _bounceCtrl.isAnimating ? _bounceCtrl.value : 0.0;
        final blink = _blinkCtrl.value;
        final particle = _particleCtrl.value;

        // --- transforms ---
        final breathCurve = math.sin(breath * math.pi);
        final floatY =
            breathCurve * 10 * (1.0 + _bounceEnergy * 0.5);
        final tiltCurve = math.sin(head * 2 * math.pi);
        final tilt = tiltCurve * 0.03 * (1.0 + _bounceEnergy);
        final bounceCurve = math.sin(bounce * 2 * math.pi);
        final bounceY = bounceCurve * 3 * _bounceEnergy;
        final mouthScale = _mouthValue;

        final blinkScaleY = blink < 0.5
            ? 1.0 - blink * 0.12
            : 0.94 + (blink - 0.5) * 0.12;

        final danceSway = widget.animState == 'dancing'
            ? math.sin(bounce * 3 * math.pi) * 0.06
            : 0.0;

        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ---- backdrop glow ----
              Positioned(
                bottom: 20,
                child: Transform.scale(
                  scale: 1.0 + breathCurve * 0.04,
                  child: Container(
                    width: 200,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, // Will be ellipse due to w≠h
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ---- floating particles ----
              ..._buildParticles(particle),

              // ---- character image ----
              Transform.translate(
                offset: Offset(danceSway * 20, -floatY - bounceY * 4),
                child: Transform.rotate(
                  angle: tilt + danceSway,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(1, 1, blinkScaleY),
                    alignment: const Alignment(0, -0.4),
                    child: Image.asset(
                      'assets/character.png',
                      height: 320,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // ---- mouth indicator (talking glow) ----
              if (widget.animState == 'talking')
                Positioned(
                  bottom: 95,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: mouthScale * 0.6,
                    child: Container(
                      width: 40 + mouthScale * 20,
                      height: 8 + mouthScale * 6,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(double t) {
    // 3 subtle floating dots that orbit around the character
    return [
      _particle(t * 1.0, 0, -120, 6),
      _particle(t * 1.0 + 2.1, math.pi * 0.66, -80, 4),
      _particle(t * 1.0 + 4.2, math.pi * 1.33, -100, 5),
    ];
  }

  Widget _particle(double t, double phase, double yBase, double size) {
    final x = math.sin(t + phase) * 60;
    final y = yBase + math.cos(t + phase) * 15;
    final opacity = 0.15 + 0.1 * math.sin(t * 3 + phase);

    return Positioned(
      bottom: 50,
      child: Transform.translate(
        offset: Offset(x, y),
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
