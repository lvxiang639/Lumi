import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

enum PetPosition { bottomBar, sidebar }

// Simple elegant SVG cat — standing/walking pose
const _catSvg = '''
<svg viewBox="0 0 120 80" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  <path d="M15 45 Q5 35 8 25 Q10 18 18 30 Q20 35 22 42" stroke="#E0960C" stroke-width="3.5" fill="none" stroke-linecap="round"/>
  <!-- Back left leg -->
  <line id="leg-bl" x1="30" y1="50" x2="30" y2="68" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
  <circle cx="30" cy="70" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
  <!-- Back right leg -->
  <line id="leg-br" x1="42" y1="50" x2="42" y2="66" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
  <circle cx="42" cy="68" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
  <!-- Body -->
  <ellipse cx="48" cy="44" rx="22" ry="11" fill="#F5A623"/>
  <ellipse cx="48" cy="44" rx="22" ry="11" fill="none" stroke="#D4891A" stroke-width="1.5"/>
  <!-- Belly -->
  <ellipse cx="50" cy="47" rx="12" ry="6" fill="white" opacity="0.8"/>
  <!-- Body stripes -->
  <line x1="35" y1="36" x2="35" y2="52" stroke="#E0960C" stroke-width="2.5" opacity="0.6"/>
  <line x1="45" y1="34" x2="45" y2="54" stroke="#E0960C" stroke-width="2.5" opacity="0.6"/>
  <line x1="55" y1="34" x2="55" y2="54" stroke="#E0960C" stroke-width="2.5" opacity="0.6"/>
  <!-- Front left leg -->
  <line id="leg-fl" x1="58" y1="52" x2="58" y2="67" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
  <circle cx="58" cy="69" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
  <!-- Front right leg -->
  <line id="leg-fr" x1="65" y1="52" x2="65" y2="65" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
  <circle cx="65" cy="67" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
  <!-- Neck -->
  <ellipse cx="68" cy="36" rx="5" ry="8" fill="#F5A623"/>
  <!-- Head -->
  <ellipse cx="76" cy="28" rx="12" ry="10" fill="#F5A623"/>
  <ellipse cx="76" cy="28" rx="12" ry="10" fill="none" stroke="#D4891A" stroke-width="1.2"/>
  <!-- Left ear -->
  <polygon points="70,20 65,8 76,18" fill="#F5A623" stroke="#D4891A" stroke-width="1"/>
  <polygon points="71,19 67,10 75,18" fill="#FFB6C1" opacity="0.7"/>
  <!-- Right ear -->
  <polygon points="80,19 84,7 87,18" fill="#F5A623" stroke="#D4891A" stroke-width="1"/>
  <polygon points="81,18 84,9 86,18" fill="#FFB6C1" opacity="0.7"/>
  <!-- Eyes -->
  <ellipse cx="73" cy="27" rx="2.5" ry="3" fill="#4A3520"/>
  <ellipse cx="80" cy="27" rx="2.5" ry="3" fill="#4A3520"/>
  <circle cx="73.5" cy="26" r="0.8" fill="white"/>
  <circle cx="80.5" cy="26" r="0.8" fill="white"/>
  <!-- Nose -->
  <ellipse cx="76" cy="31" rx="2" ry="1.2" fill="#FF6B8A"/>
  <!-- Mouth -->
  <path d="M76 32 L74 34 M76 32 L78 34" stroke="#D4891A" stroke-width="0.6" fill="none"/>
  <!-- Whiskers -->
  <line x1="68" y1="30" x2="56" y2="28" stroke="white" stroke-width="0.5" opacity="0.8"/>
  <line x1="68" y1="31" x2="56" y2="31" stroke="white" stroke-width="0.5" opacity="0.8"/>
  <line x1="84" y1="30" x2="96" y2="28" stroke="white" stroke-width="0.5" opacity="0.8"/>
  <line x1="84" y1="31" x2="96" y2="31" stroke="white" stroke-width="0.5" opacity="0.8"/>
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
