import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PetPosition { bottomBar, sidebar }

// Walk cycle frame 1 — left legs forward
const _f1 = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
<defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs>
<path d="M20 64 Q8 58 6 46 Q5 38 10 34" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/>
<ellipse cx="44" cy="68" rx="17" ry="13" fill="#FFB347"/>
<ellipse cx="46" cy="71" rx="10" ry="7" fill="white" opacity="0.6"/>
<line x1="34" y1="74" x2="30" y2="88" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="30" cy="90" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="50" y1="74" x2="54" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="54" cy="88" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="40" y1="76" x2="44" y2="87" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="44" cy="89" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="52" y1="74" x2="48" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="48" cy="88" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<circle cx="50" cy="44" r="24" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<circle cx="50" cy="46" r="15" fill="white" opacity=".2"/>
<polygon points="30,28 20,8 38,18" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<polygon points="30,25 23,12 35,20" fill="#FFB6C1" opacity=".5"/>
<polygon points="64,22 74,6 76,18" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<polygon points="67,20 72,10 74,18" fill="#FFB6C1" opacity=".5"/>
<ellipse cx="42" cy="42" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="42" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
<circle cx="41" cy="39" r="2" fill="white"/><circle cx="43.5" cy="43.5" r="1" fill="white"/>
<ellipse cx="58" cy="42" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="58" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
<circle cx="57" cy="39" r="2" fill="white"/><circle cx="59.5" cy="43.5" r="1" fill="white"/>
<circle cx="35" cy="50" r="6" fill="url(#b)"/><circle cx="65" cy="50" r="6" fill="url(#b)"/>
<polygon points="50,48 48,50 52,50" fill="#FF6B8A"/>
<path d="M46 51 Q48 54 50 51 Q52 54 54 51" stroke="#8B5E3C" stroke-width="1" fill="none"/>
</svg>''';

// Walk cycle frame 2 — right legs forward
const _f2 = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
<defs><radialGradient id="b" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFB6C1" stop-opacity="0.7"/><stop offset="100%" stop-color="#FFB6C1" stop-opacity="0"/></radialGradient></defs>
<path d="M20 64 Q10 56 8 44 Q7 36 12 32" stroke="#FF8C42" stroke-width="4" fill="none" stroke-linecap="round"/>
<ellipse cx="44" cy="68" rx="17" ry="13" fill="#FFB347"/>
<ellipse cx="46" cy="71" rx="10" ry="7" fill="white" opacity="0.6"/>
<line x1="34" y1="74" x2="38" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="38" cy="88" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="50" y1="74" x2="46" y2="88" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="46" cy="90" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="40" y1="76" x2="36" y2="86" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="36" cy="88" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<line x1="52" y1="74" x2="56" y2="87" stroke="#D4891A" stroke-width="5" stroke-linecap="round"/>
<circle cx="56" cy="89" r="3.5" fill="white" stroke="#D4891A" stroke-width="1"/>
<circle cx="50" cy="44" r="24" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<circle cx="50" cy="46" r="15" fill="white" opacity=".2"/>
<polygon points="30,28 20,8 38,18" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<polygon points="30,25 23,12 35,20" fill="#FFB6C1" opacity=".5"/>
<polygon points="64,22 74,6 76,18" fill="#FFB347" stroke="#FF8C42" stroke-width=".8"/>
<polygon points="67,20 72,10 74,18" fill="#FFB6C1" opacity=".5"/>
<ellipse cx="42" cy="42" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="42" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
<circle cx="41" cy="39" r="2" fill="white"/><circle cx="43.5" cy="43.5" r="1" fill="white"/>
<ellipse cx="58" cy="42" rx="5" ry="6" fill="#2D1B00"/><ellipse cx="58" cy="41" rx="3.5" ry="4.5" fill="#4A3000"/>
<circle cx="57" cy="39" r="2" fill="white"/><circle cx="59.5" cy="43.5" r="1" fill="white"/>
<circle cx="35" cy="50" r="6" fill="url(#b)"/><circle cx="65" cy="50" r="6" fill="url(#b)"/>
<polygon points="50,48 48,50 52,50" fill="#FF6B8A"/>
<path d="M46 51 Q48 54 50 51 Q52 54 54 51" stroke="#8B5E3C" stroke-width="1" fill="none"/>
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
  late AnimationController _frameCtrl;
  bool _started = false;
  double _screenW = 400, _walkX = 0;
  bool _movingRight = true;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _frameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _screenW = MediaQuery.of(context).size.width;
      _walkX = _screenW * 0.15;
      _startWalking();
    }
  }

  void _startWalking() {
    if (!mounted) return;
    final end = _movingRight ? _screenW - 40.0 : 40.0;
    final dist = (end - _walkX).abs();
    final dur = (dist / _screenW * 20000).toInt().clamp(8000, 25000);
    _walkCtrl.duration = Duration(milliseconds: dur);
    _walkCtrl.forward(from: 0).then((_) {
      if (mounted) { _movingRight = !_movingRight; _walkX = end; _startWalking(); }
    });
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
        _walkX = _movingRight
            ? lerpDouble(_walkX, _screenW - 40, _walkCtrl.value)!
            : lerpDouble(_walkX, 40, _walkCtrl.value)!;
        final bob = sin(_walkCtrl.value * 3.14 * 6) * 2.5;
        final frame = (_frameCtrl.value * 1000).toInt() % 400 < 200 ? _f1 : _f2;

        return Positioned(
          left: _walkX, bottom: 2,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Transform.translate(
              offset: Offset(0, bob),
              child: Transform.flip(flipX: !_movingRight, child: SvgPicture.string(frame, width: 64, height: 50)),
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
        decoration: BoxDecoration(
          color: const Color(0xFFFFB347).withValues(alpha: 0.4),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
        ),
        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 16))),
      ),
    ),
  );
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
