import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PetPosition { bottomBar, chatInput, sidebar }

String petEmoji(String emotion) {
  switch (emotion) {
    case 'joy': return '🦏';
    case 'sad': return '🦏';
    case 'angry': return '🦏';
    case 'surprised': return '🦏';
    case 'worried': return '🦏';
    default: return '🦏'; // rhino for "犀" — the horned spirit
  }
}

class PetCat extends StatefulWidget {
  final PetPosition position;
  final VoidCallback? onTap;
  final bool isThinking;
  final String emotion;

  const PetCat({
    super.key,
    this.position = PetPosition.bottomBar,
    this.onTap,
    this.isThinking = false,
    this.emotion = 'calm',
  });

  @override
  State<PetCat> createState() => _PetCatState();
}

class _PetCatState extends State<PetCat> with TickerProviderStateMixin {
  late AnimationController _walkCtrl;
  late AnimationController _bobCtrl;
  late Animation<double> _walkX;
  late Animation<double> _bobY;
  bool _movingRight = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bobY = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startWalking();
    }
  }

  void _startWalking() {
    final screenW = MediaQuery.of(context).size.width;
    final startX = _movingRight ? -40.0 : screenW;
    final endX = _movingRight ? screenW : -40.0;

    _walkX = Tween<double>(begin: startX, end: endX).animate(
      CurvedAnimation(parent: _walkCtrl, curve: Curves.linear));

    _walkCtrl.forward(from: 0).then((_) {
      if (mounted) {
        _movingRight = !_movingRight;
        _startWalking();
      }
    });
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    _bobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) {
      return _sidebarCat();
    }
    return _walkingCat();
  }

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: Listenable.merge([_walkCtrl, _bobCtrl]),
      builder: (_, __) {
        final flip = _movingRight ? 1.0 : -1.0;
        return Transform.translate(
          offset: Offset(_walkX.value, _bobY.value),
          child: Transform.scale(
            scaleX: flip,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Horn glow
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)],
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome, size: 8, color: Color(0xFFFFD54F)),
                  ),
                ),
                const SizedBox(height: 2),
                // Rhino emoji (represents 灵犀 - the horned spirit)
                Text(petEmoji(widget.emotion), style: const TextStyle(fontSize: 40)),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _sidebarCat() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 28,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_awesome, size: 10, color: Color(0xFFFFD54F)),
          SizedBox(height: 2),
          Text('🦏', style: TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }

  // ── Chat resting ──
  static Widget chatResting({bool isThinking = false, String emotion = 'calm'}) {
    return petCatResting(isThinking: isThinking, emotion: emotion);
  }
}

// ── Resting cat on input bar ──

class _ChatRestingCat extends StatefulWidget {
  final bool isThinking;
  final String emotion;
  const _ChatRestingCat({required this.isThinking, this.emotion = 'calm'});

  @override
  State<_ChatRestingCat> createState() => _ChatRestingCatState();
}

class _ChatRestingCatState extends State<_ChatRestingCat>
    with SingleTickerProviderStateMixin {
  late AnimationController _headCtrl;

  @override
  void initState() {
    super.initState();
    _headCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _headCtrl,
      builder: (_, __) {
        final tilt = widget.isThinking ? sin(_headCtrl.value * 3.14) * 0.12 : 0.0;
        return Transform.rotate(
          angle: tilt,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 1),
            Text(petEmoji(widget.emotion), style: const TextStyle(fontSize: 28)),
          ]),
        );
      },
    );
  }
}

Widget petCatResting({bool isThinking = false, String emotion = 'calm'}) {
  return _ChatRestingCat(isThinking: isThinking, emotion: emotion);
}
