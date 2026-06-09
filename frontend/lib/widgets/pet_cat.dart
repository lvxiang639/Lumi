import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

enum PetPosition { bottomBar, sidebar }

// Q-version chibi cat SVG — big head, big eyes, tiny body, blush cheeks
const _catSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="blush" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <!-- Tail — curved behind -->
  <path d="M22 62 Q8 55 5 42 Q3 33 10 28" stroke="#FF8C42" stroke-width="4.5" fill="none" stroke-linecap="round"/>
  <!-- Body — small egg shape -->
  <ellipse cx="42" cy="68" rx="18" ry="14" fill="#FFB347"/>
  <!-- Belly -->
  <ellipse cx="44" cy="71" rx="10" ry="8" fill="white" opacity="0.7"/>
  <!-- Back legs (behind body) -->
  <ellipse cx="32" cy="78" rx="6" ry="4" fill="#FFB347"/>
  <ellipse cx="28" cy="82" rx="5" ry="3" fill="white"/>
  <ellipse cx="48" cy="78" rx="6" ry="4" fill="#FFB347"/>
  <ellipse cx="44" cy="82" rx="5" ry="3" fill="white"/>
  <!-- Front legs (in front) -->
  <ellipse cx="38" cy="76" rx="5" ry="6" fill="#FFB347"/>
  <ellipse cx="34" cy="82" rx="4.5" ry="3" fill="white"/>
  <ellipse cx="50" cy="74" rx="5" ry="6" fill="#FFB347"/>
  <ellipse cx="46" cy="80" rx="4.5" ry="3" fill="white"/>
  <!-- Head — BIG circle (Q-version proportion) -->
  <circle cx="48" cy="44" r="25" fill="#FFB347"/>
  <circle cx="48" cy="44" r="25" fill="none" stroke="#FF8C42" stroke-width="0.8"/>
  <!-- Head lighter patch -->
  <circle cx="48" cy="46" r="16" fill="white" opacity="0.25"/>
  <!-- Left ear -->
  <polygon points="28,28 18,6 36,18" fill="#FFB347" stroke="#FF8C42" stroke-width="0.8" stroke-linejoin="round"/>
  <polygon points="28,24 22,10 33,20" fill="#FFB6C1" opacity="0.6"/>
  <!-- Right ear -->
  <polygon points="62,22 72,4 74,18" fill="#FFB347" stroke="#FF8C42" stroke-width="0.8" stroke-linejoin="round"/>
  <polygon points="66,20 70,8 72,18" fill="#FFB6C1" opacity="0.6"/>
  <!-- Left eye — big sparkly anime eye -->
  <ellipse cx="40" cy="42" rx="5.5" ry="6.5" fill="#2D1B00"/>
  <ellipse cx="40" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
  <circle cx="39" cy="39" r="2" fill="white"/>
  <circle cx="41.5" cy="43.5" r="1" fill="white"/>
  <!-- Right eye -->
  <ellipse cx="56" cy="42" rx="5.5" ry="6.5" fill="#2D1B00"/>
  <ellipse cx="56" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
  <circle cx="55" cy="39" r="2" fill="white"/>
  <circle cx="57.5" cy="43.5" r="1" fill="white"/>
  <!-- Blush cheeks -->
  <circle cx="33" cy="50" r="6" fill="url(#blush)"/>
  <circle cx="63" cy="50" r="6" fill="url(#blush)"/>
  <!-- Nose — tiny triangle -->
  <polygon points="48,48 46,50 50,50" fill="#FF6B8A"/>
  <!-- Mouth — cute w shape -->
  <path d="M44 51 Q46 54 48 51 Q50 54 52 51" stroke="#8B5E3C" stroke-width="1.2" fill="none" stroke-linecap="round"/>
  <!-- Whiskers -->
  <line x1="28" y1="48" x2="10" y2="44" stroke="#8B5E3C" stroke-width="0.7" opacity="0.5"/>
  <line x1="28" y1="50" x2="10" y2="50" stroke="#8B5E3C" stroke-width="0.7" opacity="0.5"/>
  <line x1="68" y1="48" x2="86" y2="44" stroke="#8B5E3C" stroke-width="0.7" opacity="0.5"/>
  <line x1="68" y1="50" x2="86" y2="50" stroke="#8B5E3C" stroke-width="0.7" opacity="0.5"/>
</svg>''';

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
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
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
    final end = _movingRight ? _screenW - 80.0 : 80.0;
    final dist = (end - _walkX).abs();
    // Slow walk: 15-30 seconds per screen width
    final duration = (dist / _screenW * 25000).toInt().clamp(8000, 30000);

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
            ? lerpDouble(_walkX, _screenW - 80, t)!
            : lerpDouble(_walkX, 80, t)!;

        // Walking bob effect
        final bob = sin(t * 3.14 * 4) * 3;
        final isWalking = _walkCtrl.isAnimating;

        return Positioned(
          left: _walkX,
          bottom: 2,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Transform.translate(
              offset: Offset(0, bob),
              child: Transform.flip(
                flipX: !_movingRight,
                child: SvgPicture.string(
                  _catSvg,
                  width: 72,
                  height: 44,
                ),
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
      bottom: 50,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SvgPicture.string(
          _catSvg,
          width: 36,
          height: 22,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
    );
  }
}

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
