import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PetPosition { bottomBar, sidebar, paused }

// ── 4-frame walk cycle SVG (cat pacing gait) ──
const _frames = [
  // 0: left front up, right back up
  '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M22 64 Q10 56 8 46" stroke="#FF8C42" stroke-width="3.5" fill="none" stroke-linecap="round"/><ellipse cx="44" cy="67" rx="16" ry="12" fill="#FFB347"/><ellipse cx="46" cy="70" rx="9" ry="6" fill="white" opacity="0.5"/><line x1="34" y1="72" x2="32" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="32" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="50" y1="72" x2="52" y2="84" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="52" cy="86" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="40" y1="74" x2="36" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="36" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="52" y1="74" x2="55" y2="84" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="55" cy="86" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><circle cx="48" cy="42" r="23" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="48" cy="44" r="14" fill="white" opacity=".15"/><polygon points="28,26 18,6 36,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="28,23 21,10 33,18" fill="#FFB6C1" opacity=".5"/><polygon points="62,20 72,4 74,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="65,18 70,8 72,16" fill="#FFB6C1" opacity=".5"/><ellipse cx="40" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="40" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="39" cy="37" r="2" fill="white"/><ellipse cx="56" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="56" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="55" cy="37" r="2" fill="white"/><circle cx="33" cy="48" r="5" fill="url(#b)"/><circle cx="63" cy="48" r="5" fill="url(#b)"/><polygon points="48,46 46,48 50,48" fill="#FF6B8A"/></svg>''',
  // 1: all legs middle (transition)
  '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M22 64 Q8 58 6 48" stroke="#FF8C42" stroke-width="3.5" fill="none" stroke-linecap="round"/><ellipse cx="44" cy="67" rx="16" ry="12" fill="#FFB347"/><ellipse cx="46" cy="70" rx="9" ry="6" fill="white" opacity="0.5"/><line x1="34" y1="72" x2="33" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="33" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="50" y1="72" x2="50" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="50" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="40" y1="74" x2="39" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="39" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="52" y1="74" x2="53" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="53" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><circle cx="48" cy="42" r="23" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="48" cy="44" r="14" fill="white" opacity=".15"/><polygon points="28,26 18,6 36,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="28,23 21,10 33,18" fill="#FFB6C1" opacity=".5"/><polygon points="62,20 72,4 74,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="65,18 70,8 72,16" fill="#FFB6C1" opacity=".5"/><ellipse cx="40" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="40" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="39" cy="37" r="2" fill="white"/><ellipse cx="56" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="56" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="55" cy="37" r="2" fill="white"/><circle cx="33" cy="48" r="5" fill="url(#b)"/><circle cx="63" cy="48" r="5" fill="url(#b)"/><polygon points="48,46 46,48 50,48" fill="#FF6B8A"/></svg>''',
  // 2: right front up, left back up
  '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M20 64 Q6 58 4 46" stroke="#FF8C42" stroke-width="3.5" fill="none" stroke-linecap="round"/><ellipse cx="44" cy="67" rx="16" ry="12" fill="#FFB347"/><ellipse cx="46" cy="70" rx="9" ry="6" fill="white" opacity="0.5"/><line x1="34" y1="72" x2="37" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="37" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="50" y1="72" x2="48" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="48" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="40" y1="74" x2="43" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="43" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="52" y1="74" x2="50" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="50" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><circle cx="48" cy="42" r="23" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="48" cy="44" r="14" fill="white" opacity=".15"/><polygon points="28,26 18,6 36,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="28,23 21,10 33,18" fill="#FFB6C1" opacity=".5"/><polygon points="62,20 72,4 74,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="65,18 70,8 72,16" fill="#FFB6C1" opacity=".5"/><ellipse cx="40" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="40" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="39" cy="37" r="2" fill="white"/><ellipse cx="56" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="56" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="55" cy="37" r="2" fill="white"/><circle cx="33" cy="48" r="5" fill="url(#b)"/><circle cx="63" cy="48" r="5" fill="url(#b)"/><polygon points="48,46 46,48 50,48" fill="#FF6B8A"/></svg>''',
  // 3: all legs middle (transition)
  '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M22 64 Q10 56 8 48" stroke="#FF8C42" stroke-width="3.5" fill="none" stroke-linecap="round"/><ellipse cx="44" cy="67" rx="16" ry="12" fill="#FFB347"/><ellipse cx="46" cy="70" rx="9" ry="6" fill="white" opacity="0.5"/><line x1="34" y1="72" x2="33" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="33" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="50" y1="72" x2="50" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="50" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="40" y1="74" x2="39" y2="86" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="39" cy="88" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><line x1="52" y1="74" x2="53" y2="85" stroke="#D4891A" stroke-width="4.5" stroke-linecap="round"/><circle cx="53" cy="87" r="3" fill="white" stroke="#D4891A" stroke-width="1"/><circle cx="48" cy="42" r="23" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="48" cy="44" r="14" fill="white" opacity=".15"/><polygon points="28,26 18,6 36,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="28,23 21,10 33,18" fill="#FFB6C1" opacity=".5"/><polygon points="62,20 72,4 74,16" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><polygon points="65,18 70,8 72,16" fill="#FFB6C1" opacity=".5"/><ellipse cx="40" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="40" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="39" cy="37" r="2" fill="white"/><ellipse cx="56" cy="40" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="56" cy="39" rx="3.5" ry="4.5" fill="#4A3000"/><circle cx="55" cy="37" r="2" fill="white"/><circle cx="33" cy="48" r="5" fill="url(#b)"/><circle cx="63" cy="48" r="5" fill="url(#b)"/><polygon points="48,46 46,48 50,48" fill="#FF6B8A"/></svg>''',
];

class PetCat extends StatefulWidget {
  final PetPosition position;
  final VoidCallback? onTap;
  const PetCat({super.key, this.position = PetPosition.bottomBar, this.onTap});
  @override
  State<PetCat> createState() => _PetCatState();
}

class _PetCatState extends State<PetCat> with TickerProviderStateMixin {
  late AnimationController _walkCtrl;
  late AnimationController _frameCtrl;
  late AnimationController _swayCtrl;
  bool _started = false;
  double _screenW = 400, _walkX = 0;
  bool _movingRight = true;
  int _stepCount = 0;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _frameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();
    _swayCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    _walkCtrl.addStatusListener((s) {
      if ((s == AnimationStatus.completed || s == AnimationStatus.dismissed) && mounted && ++_stepCount < 3) {
        _movingRight = !_movingRight;
        _startWalking();
      } else if (mounted && _stepCount >= 3) {
        // Pause and look around
        _stepCount = 0;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) { _movingRight = !_movingRight; _startWalking(); }
        });
      }
    });
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
    final end = _movingRight ? _screenW - 60.0 : 60.0;
    final dist = (end - _walkX).abs();
    final dur = (dist / _screenW * 25000).toInt().clamp(12000, 35000);
    _walkCtrl.duration = Duration(milliseconds: dur);
    if (_movingRight) _walkCtrl.forward(from: _walkCtrl.value);
    else _walkCtrl.reverse(from: _walkCtrl.value);
  }

  @override
  void dispose() { _walkCtrl.dispose(); _frameCtrl.dispose(); _swayCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) return _sidebarCat();
    return _walkingCat();
  }

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: Listenable.merge([_walkCtrl, _frameCtrl, _swayCtrl]),
      builder: (_, __) {
        _walkX = _movingRight ? (lerpDouble(_walkX, _screenW - 60, _walkCtrl.value) ?? _walkX) : (lerpDouble(_walkX, 60, _walkCtrl.value) ?? _walkX);

        // Smooth bob + body sway
        final bob = sin(_walkCtrl.value * 3.14 * 8) * 2;
        final sway = sin(_swayCtrl.value * 3.14 * 2) * 1.5;
        final frameIdx = ((_frameCtrl.value * 1000) ~/ 175) % 4;

        return Positioned(
          left: _walkX,
          bottom: 2,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Transform.translate(
              offset: Offset(sway, bob),
              child: Transform.flip(
                flipX: !_movingRight,
                child: SvgPicture.string(_frames[frameIdx], width: 64, height: 50),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sidebarCat() => Positioned(
    right: 0, bottom: 50,
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 28, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFFFB347).withValues(alpha: 0.4), borderRadius: const BorderRadius.horizontal(right: Radius.circular(14))),
        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 16))),
      ),
    ),
  );
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
