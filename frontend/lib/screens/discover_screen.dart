import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/discover_provider.dart';
import '../theme/app_colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _commentingId;
  final _commentCtrl = TextEditingController();
  final Set<String> _expandedIds = {};

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  String _formatTime(DateTime dt) {
    final now = DateTime.now(); final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  String _skillLabel(String? skill) {
    switch (skill) {
      case 'greeting': return '灵犀问候';
      case 'weather': return '天气提醒';
      case 'calendar': return '日程提醒';
      case 'expense': return '记账提醒';
      case 'memory': return '记忆话题';
      case 'emotion': return '情绪关怀';
      case 'morning_briefing': return '晨间简报';
      case 'daily_content': return '每日精选';
      case 'news': return '本地资讯';
      case 'chinese_literature': return '国学经典';
      case 'interest_push': return '你可能感兴趣';
      default: return '灵犀';
    }
  }

  IconData _skillIcon(String? skill) {
    switch (skill) {
      case 'greeting': return Icons.waving_hand;
      case 'weather': return Icons.wb_sunny_outlined;
      case 'calendar': return Icons.calendar_month_outlined;
      case 'expense': return Icons.account_balance_wallet_outlined;
      case 'memory': return Icons.psychology_outlined;
      case 'emotion': return Icons.emoji_emotions_outlined;
      case 'morning_briefing': return Icons.wb_twilight;
      case 'daily_content': return Icons.auto_awesome;
      case 'news': return Icons.newspaper;
      case 'chinese_literature': return Icons.menu_book_outlined;
      case 'interest_push': return Icons.lightbulb_outline;
      default: return Icons.pets;
    }
  }

  Color _skillColor(String? skill) {
    switch (skill) {
      case 'greeting': return const Color(0xFFF59E0B);
      case 'weather': return const Color(0xFF06B6D4);
      case 'calendar': return const Color(0xFF3B82F6);
      case 'expense': return const Color(0xFF10B981);
      case 'memory': return const Color(0xFF8B5CF6);
      case 'emotion': return const Color(0xFFEC4899);
      case 'morning_briefing': return const Color(0xFFF97316);
      case 'daily_content': return const Color(0xFF6366F1);
      case 'news': return const Color(0xFFF97316);
      case 'chinese_literature': return const Color(0xFF7C3AED);
      case 'interest_push': return const Color(0xFFF59E0B);
      default: return AppColors.accent;
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Consumer<DiscoverProvider>(
      builder: (ctx, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(b),
          appBar: AppBar(
            title: Row(children: [
              const Text('发现', style: TextStyle(fontWeight: FontWeight.w600)),
              if (provider.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                  child: Text('${provider.unreadCount > 99 ? '99+' : provider.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          body: provider.items.isEmpty
              ? _emptyState(b)
              : RefreshIndicator(
                  onRefresh: () async {
                    provider.refreshDailyContent();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: provider.items.length,
                    itemBuilder: (ctx, i) {
                      final item = provider.items[i];
                      if (item.skill == 'daily_content' && item.data != null) {
                        return _dailyContentCard(item, b);
                      }
                      if (item.skill == 'interest_push' && item.data != null) {
                        return _interestCard(item, b);
                      }
                      return _momentsCard(item, b);
                    },
                  ),
                ),
        );
      },
    );
  }

  // ── Generic moments card ──

  Widget _momentsCard(DiscoverItem item, Brightness b) {
    final isNews = item.skill == 'news';
    final color = _skillColor(item.skill);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: b == Brightness.light ? 0.04 : 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(_skillIcon(item.skill), color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_skillLabel(item.skill), style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_formatTime(item.createdAt), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 10),
          // Body text
          Text(item.text, style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6)),
          // News items (tappable)
          if (isNews && item.newsItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...item.newsItems.take(3).map((n) {
              final url = n['link'] as String? ?? '';
              final title = n['title'] as String? ?? '';
              final site = n['site'] as String? ?? '';
              return GestureDetector(
                onTap: () => _openUrl(url),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.language, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: TextStyle(color: AppColors.accentBlue, fontSize: 13, decoration: TextDecoration.underline, decorationColor: AppColors.accentBlue.withValues(alpha: 0.3)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (site.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(site, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)),
                    ],
                  ]),
                ),
              );
            }),
          ],
          const SizedBox(height: 6),
          Divider(height: 1, color: AppColors.border(b).withValues(alpha: 0.4)),
          _actionBar(item, b),
        ]),
      ),
    );
  }

  // ── Action bar (like / comment / copy) ──

  Widget _actionBar(DiscoverItem item, Brightness b) {
    final showComments = item.comments.isNotEmpty;
    final expanded = _expandedIds.contains(item.id);
    final visibleComments = expanded ? item.comments : item.comments.take(3).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.read<DiscoverProvider>().toggleLike(item.id),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.liked ? Icons.favorite : Icons.favorite_border, size: 18,
                color: item.liked ? Colors.red : AppColors.textSecondary(b).withValues(alpha: 0.5)),
              if (item.likeCount > 0) ...[
                const SizedBox(width: 4), Text('${item.likeCount}', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => setState(() => _commentingId = _commentingId == item.id ? null : item.id),
            child: Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary(b).withValues(alpha: 0.5)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: item.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1))); },
            child: Icon(Icons.copy, size: 16, color: AppColors.textSecondary(b).withValues(alpha: 0.5)),
          ),
        ]),
      ),
      // Comments
      if (showComments || _commentingId == item.id)
        Container(
          margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: b == Brightness.light ? const Color(0xFFF0F0F5) : const Color(0xFF1E2229),
            borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...visibleComments.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💬', style: const TextStyle(fontSize: 11)), const SizedBox(width: 4),
                Expanded(child: Text(c, style: TextStyle(color: AppColors.text(b), fontSize: 13, height: 1.4))),
              ]),
            )),
            if (item.comments.length > 3)
              GestureDetector(
                onTap: () => setState(() => expanded ? _expandedIds.remove(item.id) : _expandedIds.add(item.id)),
                child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(expanded ? '收起' : '展开全部 ${item.comments.length} 条', style: TextStyle(color: AppColors.accent, fontSize: 11))),
              ),
            if (_commentingId == item.id)
              Row(children: [
                const Text('💬', style: TextStyle(fontSize: 14)), const SizedBox(width: 6),
                Expanded(child: TextField(
                  controller: _commentCtrl, autofocus: true,
                  style: TextStyle(color: AppColors.text(b), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '写评论...',
                    hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border(b))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onSubmitted: (v) { if (v.trim().isNotEmpty) { context.read<DiscoverProvider>().addComment(item.id, v.trim()); _commentCtrl.clear(); } },
                )),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    if (_commentCtrl.text.trim().isNotEmpty) {
                      context.read<DiscoverProvider>().addComment(item.id, _commentCtrl.text.trim());
                      _commentCtrl.clear();
                    }
                    setState(() => _commentingId = null);
                  },
                  child: const Text('发送', style: TextStyle(fontSize: 13)),
                ),
              ]),
          ]),
        ),
    ]);
  }

  // ── Daily content card (multi-section) ──

  static const _sectionIcons = {
    'daily_topic': '💡',
    'content_card': '🎴',
    'chinese_poetry': '📜',
    'chinese_idiom': '📚',
    'chinese_history': '🏛️',
    'hot_trends': '🔥',
  };

  static const _sectionLabels = {
    'daily_topic': '每日话题',
    'content_card': '今日卡片',
    'chinese_poetry': '古诗词',
    'chinese_idiom': '成语',
    'chinese_history': '典故',
    'hot_trends': '热搜',
  };

  Widget _dailyContentCard(DiscoverItem item, Brightness b) {
    final data = item.data!;
    final color = _skillColor('daily_content');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: b == Brightness.light ? 0.04 : 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('每日精选', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_formatTime(item.createdAt), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 12),
          // Section cards
          ...data.entries.where((e) {
            final v = e.value;
            if (v is Map) return (v['content'] as String?)?.isNotEmpty == true;
            return v is String && v.isNotEmpty;
          }).map((e) {
            final key = e.key;
            final content = e.value is Map ? e.value['content'] as String? ?? '' : e.value.toString();
            if (content.isEmpty) return const SizedBox.shrink();
            final icon = _sectionIcons[key] ?? '📌';
            final label = _sectionLabels[key] ?? key;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(content, style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)),
              ]),
            );
          }),
          const SizedBox(height: 2),
          Divider(height: 1, color: AppColors.border(b).withValues(alpha: 0.4)),
          _actionBar(item, b),
        ]),
      ),
    );
  }

  // ── Interest push card ──

  Widget _interestCard(DiscoverItem item, Brightness b) {
    final data = item.data!;
    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final color = _skillColor('interest_push');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: b == Brightness.light ? 0.04 : 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.lightbulb_outline, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('你可能感兴趣', style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w600)),
              Text('基于你的关注 · ${_formatTime(item.createdAt)}', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((e) {
            final it = e.value;
            final title = it['title'] as String? ?? '';
            final summary = it['summary'] as String? ?? '';
            final link = it['link'] as String? ?? '';
            return GestureDetector(
              onTap: () => _openUrl(link),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: color.withValues(alpha: 0.6), width: 3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('${e.key + 1}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 12, color: AppColors.textSecondary(b).withValues(alpha: 0.4)),
                  ]),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(summary, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ]),
              ),
            );
          }),
          const SizedBox(height: 2),
          Divider(height: 1, color: AppColors.border(b).withValues(alpha: 0.4)),
          _actionBar(item, b),
        ]),
      ),
    );
  }

  // ── Empty state ──

  Widget _emptyState(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(24)),
        child: Icon(Icons.notifications_none_rounded, size: 42, color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      const SizedBox(height: 20),
      Text('还没有动态', style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('天气提醒、日程推送、主动关怀\n会在这里出现', textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, height: 1.5)),
      const SizedBox(height: 24),
      Text('💡 提示：去聊天页和灵犀说句话吧', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.6), fontSize: 12)),
    ]),
  );
}
