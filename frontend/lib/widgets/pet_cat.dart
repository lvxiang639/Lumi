import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PetPosition { bottomBar, sidebar }
enum CatBehavior { walking, sitting, stretching }

// ── 8-frame walk cycle SVG (clean Q-version) ──
const _walkFrames = [
  // 0: left-front up
  '''<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.6"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M28 62 Q18 58 16 50" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="50" cy="66" rx="18" ry="13" fill="#FFB347"/><ellipse cx="52" cy="70" rx="11" ry="7" fill="white" opacity="0.5"/><line x1="40" y1="72" x2="37" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="37" cy="88" r="3.5" fill="white"/><line x1="56" y1="72" x2="59" y2="84" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="59" cy="86" r="3.5" fill="white"/><line x1="46" y1="74" x2="43" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="43" cy="88" r="3.5" fill="white"/><line x1="58" y1="74" x2="61" y2="85" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="61" cy="87" r="3.5" fill="white"/><circle cx="55" cy="42" r="24" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="55" cy="44" r="15" fill="white" opacity=".15"/><polygon points="35,28 24,6 44,18" fill="#FFB347"/><polygon points="35,24 28,10 40,20" fill="#FFB6C1" opacity=".5"/><polygon points="70,22 80,4 82,18" fill="#FFB347"/><polygon points="72,20 78,8 80,18" fill="#FFB6C1" opacity=".5"/><ellipse cx="47" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="47" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="46" cy="37" r="2.5" fill="white"/><ellipse cx="63" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="63" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="62" cy="37" r="2.5" fill="white"/><circle cx="40" cy="48" r="6" fill="url(#b)"/><circle cx="70" cy="48" r="6" fill="url(#b)"/><polygon points="55,46 53,48 57,48" fill="#FF6B8A"/><path d="M51 49 Q53 52 55 49 Q57 52 59 49" stroke="#8B5E3C" stroke-width="1" fill="none"/></svg>''',
  // 1: transition
  '''<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.6"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M28 62 Q16 58 14 50" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="50" cy="66" rx="18" ry="13" fill="#FFB347"/><ellipse cx="52" cy="70" rx="11" ry="7" fill="white" opacity="0.5"/><line x1="40" y1="72" x2="39" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="39" cy="88" r="3.5" fill="white"/><line x1="56" y1="72" x2="57" y2="85" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="57" cy="87" r="3.5" fill="white"/><line x1="46" y1="74" x2="45" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="45" cy="88" r="3.5" fill="white"/><line x1="58" y1="74" x2="59" y2="85" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="59" cy="87" r="3.5" fill="white"/><circle cx="55" cy="42" r="24" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="55" cy="44" r="15" fill="white" opacity=".15"/><polygon points="35,28 24,6 44,18" fill="#FFB347"/><polygon points="35,24 28,10 40,20" fill="#FFB6C1" opacity=".5"/><polygon points="70,22 80,4 82,18" fill="#FFB347"/><polygon points="72,20 78,8 80,18" fill="#FFB6C1" opacity=".5"/><ellipse cx="47" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="47" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="46" cy="37" r="2.5" fill="white"/><ellipse cx="63" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="63" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="62" cy="37" r="2.5" fill="white"/><circle cx="40" cy="48" r="6" fill="url(#b)"/><circle cx="70" cy="48" r="6" fill="url(#b)"/><polygon points="55,46 53,48 57,48" fill="#FF6B8A"/><path d="M51 49 Q53 52 55 49 Q57 52 59 49" stroke="#8B5E3C" stroke-width="1" fill="none"/></svg>''',
  // 2: right-front up
  '''<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.6"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M26 62 Q14 58 12 50" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="50" cy="66" rx="18" ry="13" fill="#FFB347"/><ellipse cx="52" cy="70" rx="11" ry="7" fill="white" opacity="0.5"/><line x1="40" y1="72" x2="43" y2="85" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="43" cy="87" r="3.5" fill="white"/><line x1="56" y1="72" x2="54" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="54" cy="88" r="3.5" fill="white"/><line x1="46" y1="74" x2="49" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="49" cy="88" r="3.5" fill="white"/><line x1="58" y1="74" x2="56" y2="85" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="56" cy="87" r="3.5" fill="white"/><circle cx="55" cy="42" r="24" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="55" cy="44" r="15" fill="white" opacity=".15"/><polygon points="35,28 24,6 44,18" fill="#FFB347"/><polygon points="35,24 28,10 40,20" fill="#FFB6C1" opacity=".5"/><polygon points="70,22 80,4 82,18" fill="#FFB347"/><polygon points="72,20 78,8 80,18" fill="#FFB6C1" opacity=".5"/><ellipse cx="47" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="47" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="46" cy="37" r="2.5" fill="white"/><ellipse cx="63" cy="40" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="63" cy="39" rx="4" ry="5" fill="#4A3000"/><circle cx="62" cy="37" r="2.5" fill="white"/><circle cx="40" cy="48" r="6" fill="url(#b)"/><circle cx="70" cy="48" r="6" fill="url(#b)"/><polygon points="55,46 53,48 57,48" fill="#FF6B8A"/><path d="M51 49 Q53 52 55 49 Q57 52 59 49" stroke="#8B5E3C" stroke-width="1" fill="none"/></svg>''',
];

// Sitting + stretching frames
const _sitFrame = '''<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.6"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M30 70 Q20 65 16 56" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="50" cy="72" rx="20" ry="14" fill="#FFB347"/><ellipse cx="52" cy="76" rx="12" ry="8" fill="white" opacity="0.5"/><ellipse cx="38" cy="86" rx="7" ry="5" fill="#FFB347"/><ellipse cx="62" cy="86" rx="7" ry="5" fill="#FFB347"/><line x1="34" y1="82" x2="34" y2="90" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="34" cy="92" r="3" fill="white"/><line x1="66" y1="82" x2="66" y2="90" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="66" cy="92" r="3" fill="white"/><circle cx="55" cy="44" r="23" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="55" cy="46" r="14" fill="white" opacity=".15"/><polygon points="36,30 26,8 44,20" fill="#FFB347"/><polygon points="35,26 28,12 40,22" fill="#FFB6C1" opacity=".5"/><polygon points="68,24 78,6 80,20" fill="#FFB347"/><polygon points="70,22 76,10 78,20" fill="#FFB6C1" opacity=".5"/><ellipse cx="47" cy="42" rx="5" ry="6" fill="#2D1B00"/><circle cx="46" cy="39" r="2" fill="white"/><ellipse cx="63" cy="42" rx="5" ry="6" fill="#2D1B00"/><circle cx="62" cy="39" r="2" fill="white"/><circle cx="40" cy="50" r="5" fill="url(#b)"/><circle cx="70" cy="50" r="5" fill="url(#b)"/><polygon points="55,48 53,50 57,50" fill="#FF6B8A"/><path d="M52 48 Q55 50 55 48" stroke="#8B5E3C" stroke-width="1" fill="none"/></svg>''';
const _stretchFrame = '''<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.6"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs><path d="M22 68 Q12 62 10 52" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="50" cy="65" rx="22" ry="10" fill="#FFB347"/><ellipse cx="52" cy="68" rx="13" ry="6" fill="white" opacity="0.5"/><line x1="34" y1="74" x2="24" y2="90" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="24" cy="92" r="3.5" fill="white"/><line x1="44" y1="74" x2="40" y2="92" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="40" cy="94" r="3.5" fill="white"/><line x1="56" y1="74" x2="62" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="62" cy="88" r="3.5" fill="white"/><line x1="64" y1="72" x2="72" y2="84" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/><circle cx="72" cy="86" r="3.5" fill="white"/><circle cx="58" cy="40" r="22" fill="#FFB347" stroke="#FF8C42" stroke-width=".7"/><circle cx="58" cy="42" r="14" fill="white" opacity=".15"/><polygon points="38,28 28,6 46,18" fill="#FFB347"/><polygon points="38,24 32,10 43,20" fill="#FFB6C1" opacity=".5"/><polygon points="72,22 82,4 84,18" fill="#FFB347"/><polygon points="74,20 80,8 82,18" fill="#FFB6C1" opacity=".5"/><ellipse cx="50" cy="38" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="50" cy="37" rx="4" ry="5" fill="#4A3000"/><circle cx="49" cy="35" r="2.5" fill="white"/><ellipse cx="66" cy="38" rx="6" ry="7" fill="#2D1B00"/><ellipse cx="66" cy="37" rx="4" ry="5" fill="#4A3000"/><circle cx="65" cy="35" r="2.5" fill="white"/><circle cx="42" cy="46" r="5" fill="url(#b)"/><circle cx="74" cy="46" r="5" fill="url(#b)"/><polygon points="58,44 56,46 60,46" fill="#FF6B8A"/><path d="M54 44 Q58 48 58 44 Q60 48 62 44" stroke="#8B5E3C" stroke-width="1" fill="none"/></svg>''';

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
  bool _started = false;
  double _screenW = 400, _walkX = 0;
  bool _movingRight = true;
  CatBehavior _behavior = CatBehavior.walking;
  int _stepCount = 0;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _frameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _walkCtrl.addStatusListener((s) {
      if ((s == AnimationStatus.completed || s == AnimationStatus.dismissed) && mounted) {
        _stepCount++;
        if (_stepCount > 2 + Random().nextInt(2)) {
          _stepCount = 0;
          _switchBehavior();
        } else {
          _movingRight = !_movingRight;
          _startWalking();
        }
      }
    });
  }

  void _switchBehavior() {
    final r = Random().nextInt(3);
    if (r == 0) {
      _behavior = CatBehavior.sitting;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) { _behavior = CatBehavior.walking; _movingRight = !_movingRight; _startWalking(); }
      });
    } else if (r == 1) {
      _behavior = CatBehavior.stretching;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) { _behavior = CatBehavior.walking; _movingRight = !_movingRight; _startWalking(); }
      });
    } else {
      _behavior = CatBehavior.walking;
      _movingRight = !_movingRight;
      _startWalking();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) { _started = true; _screenW = MediaQuery.of(context).size.width; _walkX = _screenW * 0.2; _startWalking(); }
  }

  void _startWalking() {
    if (!mounted) return;
    _behavior = CatBehavior.walking;
    final end = _movingRight ? _screenW - 60.0 : 60.0;
    final dist = (end - _walkX).abs();
    final dur = (dist / _screenW * 25000).toInt().clamp(12000, 35000);
    _walkCtrl.duration = Duration(milliseconds: dur);
    if (_movingRight) _walkCtrl.forward(from: _walkCtrl.value);
    else _walkCtrl.reverse(from: _walkCtrl.value);
  }

  void _onTap() {
    setState(() => _showParticles = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showParticles = false);
    });
    widget.onTap?.call();
  }

  @override
  void dispose() { _walkCtrl.dispose(); _frameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) return _sidebarCat();
    return _walkingCat();
  }

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: Listenable.merge([_walkCtrl, _frameCtrl]),
      builder: (_, __) {
        _walkX = _movingRight ? lerpD(_walkX, _screenW - 60, _walkCtrl.value) : lerpD(_walkX, 60, _walkCtrl.value);
        final bob = _behavior == CatBehavior.walking ? sin(_walkCtrl.value * pi * 8) * 2 : 0.0;
        final frameIdx = ((_frameCtrl.value * 1000) ~/ 150) % 8;

        // Select SVG frame
        String svg;
        if (_behavior == CatBehavior.sitting) {
          svg = _sitFrame;
        } else if (_behavior == CatBehavior.stretching) {
          svg = _stretchFrame;
        } else {
          svg = _walkFrames[frameIdx % 3];
        }

        return Positioned(
          left: _walkX, bottom: 2,
          child: Stack(clipBehavior: Clip.none, children: [
            GestureDetector(
              onTap: _onTap,
              child: Transform.translate(
                offset: Offset(0, bob),
                child: Transform.flip(flipX: !_movingRight,
                  child: SvgPicture.string(svg, width: 72, height: 56)),
              ),
            ),
            // Heart particles on click
            if (_showParticles)
              ...List.generate(5, (i) {
                final angle = -pi / 2 + (i - 2) * 0.3;
                final dist = 20.0 + i * 8;
                return Positioned(
                  top: 10 + sin(angle) * dist,
                  left: 30 + cos(angle) * dist,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 0.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 1.5 - v * 0.5, child: child)),
                    child: Text(i.isEven ? '💕' : '✨', style: const TextStyle(fontSize: 14)),
                  ),
                );
              }),
          ]),
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

double lerpD(double a, double b, double t) => a + (b - a) * t;
