import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width, height;
  final double borderRadius;
  const ShimmerSkeleton({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = 6});
  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (_, __) {
      final t = _ctrl.value;
      final alpha = 0.05 + 0.07 * (t < 0.5 ? t * 2 : 2 - t * 2);
      return Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: alpha), borderRadius: BorderRadius.circular(widget.borderRadius)),
      );
    });
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16), itemCount: count,
    itemBuilder: (_, i) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        const ShimmerSkeleton(width: 40, height: 40, borderRadius: 10),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShimmerSkeleton(width: 120 + (i * 30.0) % 80, height: 14),
          const SizedBox(height: 6),
          ShimmerSkeleton(width: 200 + (i * 20.0) % 60, height: 10, borderRadius: 4),
        ])),
      ]),
    ),
  );
}

class EmptyStateWidget extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;
  const EmptyStateWidget({super.key, required this.emoji, required this.title, this.subtitle = '', this.onAction, this.actionLabel});
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(22)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36)))),
        const SizedBox(height: 20),
        Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty) ...[const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, height: 1.5))],
        if (onAction != null && actionLabel != null) ...[const SizedBox(height: 20), ElevatedButton(onPressed: onAction, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(actionLabel!))],
      ]),
    ));
  }
}

// Card decoration helpers
class AppDecorations {
  static BoxDecoration card(Brightness b) => BoxDecoration(
    color: AppColors.card(b),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: b == Brightness.light ? 0.04 : 0.08), blurRadius: 8, offset: const Offset(0, 2))],
  );

  static BoxDecoration gradientCard() => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
  );
}
