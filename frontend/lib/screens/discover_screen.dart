import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final List<_DiscoverItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    // TODO: Load from proactive_service notifications API
    // For now, show empty state with guidance
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _items.isEmpty
          ? _emptyState(brightness)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card(brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: TextStyle(
                                    color: AppColors.text(brightness),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(item.body,
                                style: TextStyle(
                                    color: AppColors.textSecondary(
                                        brightness),
                                    fontSize: 13,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                      Text(item.time,
                          style: TextStyle(
                              color: AppColors.textSecondary(brightness)
                                  .withValues(alpha: 0.5),
                              fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
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
                size: 36,
                color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('这里是发现页',
              style: TextStyle(
                  color: AppColors.text(b),
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              '定时简报、天气提醒、主动关怀消息\n会在这里展示，不再打扰你的对话',
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

class _DiscoverItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  const _DiscoverItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
  });
}
