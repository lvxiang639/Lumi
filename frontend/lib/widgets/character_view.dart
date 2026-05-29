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
    final t = _ctrl.value;
    final isDancing = widget.animState == 'dancing';
    final isTalking = widget.animState == 'talking';

    double translateY = 0;
    double rotation = 0;
    double scale = 1.0;

    if (isDancing) {
      rotation = math.sin(t * 3 * math.pi) * 0.3;
      scale = 1.0 + math.sin(t * 6 * math.pi) * 0.08;
      translateY = math.sin(t * 4 * math.pi) * 10;
    } else if (isTalking) {
      translateY = math.sin(t * 3 * math.pi) * 4;
      scale = 1.0 + (widget.mouthOpen > 0.1 ? widget.mouthOpen * 0.02 : 0);
    } else {
      translateY = math.sin(t * 2 * math.pi) * 6;
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Image.asset(
                'assets/character.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
