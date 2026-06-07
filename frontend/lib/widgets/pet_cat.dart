import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PetPosition { bottomBar, chatInput, sidebar }

String petEmoji(String emotion) {
  switch (emotion) {
    case 'joy': return '😸';
    case 'sad': return '😿';
    case 'angry': return '😾';
    case 'surprised': return '🙀';
    case 'worried': return '😿';
    default: return '🐱'; // calm
  }
}

class PetCat extends StatefulWidget {
  final PetPosition position;
  final VoidCallback? onTap;
  final bool isThinking;
  final String emotion; // joy, sad, angry, calm, surprised, worried

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
  late AnimationController _moveCtrl;
  late AnimationController _idleCtrl;
  late Animation<double> _bobAnim;
  double _xOffset = 0;
  bool _movingRight = true;

  @override
  void initState() {
    super.initState();
    // Walking animation: moves side to side
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        setState(() {
          _xOffset = _movingRight
              ? sin(_moveCtrl.value * 3.14 * 2) * 60
              : -sin(_moveCtrl.value * 3.14 * 2) * 60;
        });
      });

    // Idle bobbing
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bobAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut),
    );

    _startWalking();
  }

  void _startWalking() {
    _moveCtrl.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _movingRight = !_movingRight;
        _startWalking();
      }
    });
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.position == PetPosition.sidebar) {
      return _sidebarCat();
    }
    return _walkingCat();
  }

  // ── Walking cat (bottom bar) ──

  Widget _walkingCat() {
    return AnimatedBuilder(
      animation: Listenable.merge([_moveCtrl, _idleCtrl]),
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(_xOffset, _bobAnim.value),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(petEmoji(widget.emotion), style: TextStyle(fontSize: 22)),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sidebar collapsed cat ──

  Widget _sidebarCat() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 24,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        ),
        child: const Center(
          child: Text(petEmoji('calm'), style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

}

// ── Convenience factory ──

Widget petCatResting({bool isThinking = false, String emotion = 'calm'}) {
  return _ChatRestingCat(isThinking: isThinking, emotion: emotion);
}

// ── Resting cat on chat input bar ──

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
        final tilt = widget.isThinking ? sin(_headCtrl.value * 3.14) * 0.15 : 0.0;
        return Transform.rotate(
          angle: tilt,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(petEmoji(widget.emotion), style: const TextStyle(fontSize: 18)),
            ),
          ),
        );
      },
    );
  }
}
