import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/discover_provider.dart';
import '../theme/app_colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().markAllRead();
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day}';
  }

  String _skillLabel(String? skill) {
    switch (skill) {
      case 'greeting': return '欢迎语';
      case 'weather': return '天气提醒';
      case 'calendar': return '日程提醒';
      case 'expense': return '记账提醒';
      case 'memory': return '记忆话题';
      case 'emotion': return '情绪关怀';
      default: return '灵犀';
    }
  }

  Color _skillColor(String? skill) {
    switch (skill) {
      case 'greeting': return const Color(0xFF10B981);
      case 'weather': return const Color(0xFF3B82F6);
      case 'calendar': return const Color(0xFFF59E0B);
      case 'expense': return const Color(0xFFF97316);
      case 'memory': return const Color(0xFF8B5CF6);
      case 'emotion': return const Color(0xFFEC4899);
      default: return AppColors.accent;
    }
  }

  IconData _skillIcon(String? skill) {
    switch (skill) {
      case 'greeting': return Icons.waving_hand_outlined;
      case 'weather': return Icons.wb_sunny_outlined;
      case 'calendar': return Icons.calendar_month_outlined;
      case 'expense': return Icons.account_balance_wallet_outlined;
      case 'memory': return Icons.psychology_outlined;
      case 'emotion': return Icons.favorite_outline;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Consumer<DiscoverProvider>(
      builder: (ctx, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(brightness),
          appBar: AppBar(
            title: Row(
              children: [
                const Text('发现'),
                if (provider.unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${provider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          body: provider.items.isEmpty
              ? _emptyState(brightness)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.items.length,
                  itemBuilder: (ctx, i) {
                    final item = provider.items[i];
                    final color = _skillColor(item.skill);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card(brightness),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_skillIcon(item.skill), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(_skillLabel(item.skill),
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text(_formatTime(item.createdAt),
                                        style: TextStyle(
                                            color: AppColors.textSecondary(brightness)
                                                .withValues(alpha: 0.5),
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.text,
                                    style: TextStyle(
                                        color: AppColors.text(brightness),
                                        fontSize: 14,
                                        height: 1.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _emptyState(Brightness b) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.notifications_none,
                size: 36, color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('还没有通知',
              style: TextStyle(
                  color: AppColors.text(b),
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '天气提醒、日程推送、主动关怀\n会在这里出现，不打扰你的对话',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary(b),
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
