import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().markAllRead();
    });
  }

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
      default: return '灵犀';
    }
  }

  String _skillIcon(String? skill) {
    switch (skill) {
      case 'greeting': return '🐱';
      case 'weather': return '☀️';
      case 'calendar': return '📅';
      case 'expense': return '💰';
      case 'memory': return '🧠';
      case 'emotion': return '💭';
      case 'morning_briefing': return '🌅';
      case 'daily_content': return '📰';
      case 'news': return '📰';
      default: return '🦏';
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
            title: Row(children: [
              const Text('发现'),
              if (provider.unreadCount > 0) ...[const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                  child: Text('${provider.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ]),
          ),
          body: provider.items.isEmpty
              ? _emptyState(brightness)
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: provider.items.length,
                    itemBuilder: (ctx, i) => _momentsCard(provider.items[i], brightness),
                  ),
                ),
        );
      },
    );
  }

  Widget _momentsCard(DiscoverItem item, Brightness b) {
    if (item.skill == 'daily_content' && item.data != null) return _dailyContentCard(item, b);

    final isNews = item.skill == 'news';
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      color: AppColors.card(b),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFFB347).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(_skillIcon(item.skill), style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_skillLabel(item.skill), style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_formatTime(item.createdAt), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.6), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(item.text, style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6)),
          if (isNews && item.newsItems.isNotEmpty) ...[const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21), borderRadius: BorderRadius.circular(8)),
              child: Column(children: item.newsItems.take(3).map((n) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                const Text('·', style: TextStyle(fontSize: 16, color: Color(0xFFF97316))), const SizedBox(width: 6),
                Expanded(child: Text(n['title'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]))).toList()),
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.border(b).withValues(alpha: 0.5)),
          _actionBar(item, b),
        ]),
      ),
    );
  }

  Widget _actionBar(DiscoverItem item, Brightness b) {
    final showComments = item.comments.isNotEmpty;
    final expanded = _expandedIds.contains(item.id);
    final visibleComments = expanded ? item.comments : item.comments.take(3).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.read<DiscoverProvider>().toggleLike(item.id),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.liked ? Icons.favorite : Icons.favorite_border, size: 18, color: item.liked ? Colors.red : AppColors.textSecondary(b).withValues(alpha: 0.5)),
              if (item.likeCount > 0) ...[const SizedBox(width: 4), Text('${item.likeCount}', style: TextStyle(color: Colors.red, fontSize: 12))],
            ]),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => setState(() => _commentingId = _commentingId == item.id ? null : item.id),
            child: Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary(b).withValues(alpha: 0.5)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: item.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制，去聊天页发送吧 💬'), duration: Duration(seconds: 1))); },
            child: Icon(Icons.share_outlined, size: 18, color: AppColors.accent),
          ),
        ]),
      ),
      if (showComments || _commentingId == item.id)
        Container(
          margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF0F0F5) : const Color(0xFF1E2229), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...visibleComments.map((c) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('💬', style: TextStyle(fontSize: 11)), const SizedBox(width: 4),
              Expanded(child: Text(c, style: TextStyle(color: AppColors.text(b), fontSize: 13, height: 1.4))),
            ]))),
            if (item.comments.length > 3)
              GestureDetector(
                onTap: () => setState(() => expanded ? _expandedIds.remove(item.id) : _expandedIds.add(item.id)),
                child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 2), child: Text(expanded ? '收起' : '展开全部 ${item.comments.length} 条', style: TextStyle(color: AppColors.accent, fontSize: 11))),
              ),
            if (_commentingId == item.id)
              Row(children: [
                Text('💬', style: TextStyle(fontSize: 14)), const SizedBox(width: 6),
                Expanded(child: TextField(
                  controller: _commentCtrl, autofocus: true,
                  style: TextStyle(color: AppColors.text(b), fontSize: 13),
                  decoration: InputDecoration(hintText: '写评论...', hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                  onSubmitted: (v) { if (v.trim().isNotEmpty) { context.read<DiscoverProvider>().addComment(item.id, v.trim()); _commentCtrl.clear(); } },
                )),
                TextButton(onPressed: () { if (_commentCtrl.text.trim().isNotEmpty) { context.read<DiscoverProvider>().addComment(item.id, _commentCtrl.text.trim()); _commentCtrl.clear(); } setState(() => _commentingId = null); }, child: Text('发送', style: TextStyle(fontSize: 12))),
              ]),
          ]),
        ),
    ]);
  }

  Widget _dailyContentCard(DiscoverItem item, Brightness b) {
    final data = item.data!;
    final texts = <String>[];
    for (final val in data.values) {
      if (val is Map) { final c = val['content']; if (c is String && c.isNotEmpty) texts.add(c); }
      else if (val is String && val.isNotEmpty) texts.add(val);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8), color: AppColors.card(b),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('📰', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('每日精选', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_formatTime(item.createdAt), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.6), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 10),
          if (texts.isEmpty) const Text('内容加载中...', style: TextStyle(color: Colors.grey, fontSize: 13))
          else ...texts.map((t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)))),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.border(b).withValues(alpha: 0.5)),
          _actionBar(item, b),
        ]),
      ),
    );
  }

  Widget _emptyState(Brightness b) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.notifications_none, size: 36, color: AppColors.accent.withValues(alpha: 0.5))),
    const SizedBox(height: 20), Text('还没有动态', style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8), Text('天气提醒、日程推送、主动关怀\n会在这里出现', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, height: 1.5)),
  ]));
}
