import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/conversation_provider.dart';
import '../theme/app_colors.dart';
import '../services/routes.dart';
import '../widgets/shimmer_skeleton.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Set<String> _pinnedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('pinned_convos');
      if (raw != null) {
        _pinnedIds = Set<String>.from(json.decode(raw) as List);
      }
    } catch (_) {}
  }

  Future<void> _savePins() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pinned_convos', json.encode(_pinnedIds.toList()));
  }

  void _togglePin(String id) {
    setState(() {
      if (_pinnedIds.contains(id)) {
        _pinnedIds.remove(id);
      } else {
        _pinnedIds.add(id);
      }
    });
    _savePins();
  }

  Future<void> _refresh() async {
    await context.read<ConversationProvider>().load();
  }

  void _newConversation() {
    Navigator.push(context, slideRoute(const ChatScreen())).then((_) => _refresh());
  }

  void _openConversation(String convId) {
    Navigator.push(context, slideRoute(ChatScreen(conversationId: convId))).then((_) => _refresh());
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _deleteConv(String id) async {
    await context.read<ConversationProvider>().delete(id);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        title: const Text('灵犀'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.accent),
            onPressed: _newConversation,
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading && provider.conversations.isEmpty) {
            return const SkeletonList(count: 6);
          }
          if (provider.error != null && provider.conversations.isEmpty) {
            return _errorState(brightness);
          }
          if (provider.conversations.isEmpty && _query.isEmpty) {
            return _emptyState(brightness);
          }

          final all = provider.conversations;
          // Filter
          var filtered = _query.isNotEmpty
              ? all.where((c) {
                  final t = c.title.toString();
                  final lm = (c.lastMessage ?? '').toString();
                  return t.contains(_query) || lm.contains(_query);
                }).toList()
              : List.from(all);
          // Sort: pinned first
          filtered.sort((a, b) {
            final aPin = _pinnedIds.contains(a.id as String);
            final bPin = _pinnedIds.contains(b.id as String);
            if (aPin && !bPin) return -1;
            if (!aPin && bPin) return 1;
            return 0;
          });

          return Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card(brightness),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: AppColors.text(brightness), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索对话...',
                    hintStyle: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary(brightness)),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                            child: Icon(Icons.close, size: 16, color: AppColors.textSecondary(brightness)))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('没有找到匹配的对话',
                          style: TextStyle(color: AppColors.textSecondary(brightness))))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _convItem(brightness, filtered[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _convItem(Brightness b, dynamic conv) {
    final id = conv.id as String;
    final title = conv.title as String;
    final lastMessage = conv.lastMessage as String?;
    final updatedAt = conv.updatedAt as DateTime;
    final isPinned = _pinnedIds.contains(id);
    final emoji = ['🐱', '🤖', '📝', '💡', '🎯', '🌟'][id.hashCode.abs() % 6];

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _deleteConv(id);
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: Column(children: [
        if (isPinned)
          Container(
            height: 2,
            margin: const EdgeInsets.only(left: 72),
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Stack(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            if (isPinned)
              const Positioned(top: 0, right: 0,
                child: Icon(Icons.push_pin, size: 12, color: AppColors.accent)),
          ]),
          title: Text(title,
            style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: lastMessage != null && lastMessage.isNotEmpty
              ? Text(lastMessage,
                  style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: Text(_formatRelativeTime(updatedAt),
              style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
          onTap: () => _openConversation(id),
          onLongPress: () => _showContextMenu(id, title, isPinned),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        Divider(height: 1, indent: 72, color: AppColors.border(b).withValues(alpha: 0.5)),
      ]),
    );
  }

  void _showContextMenu(String id, String title, bool isPinned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(isPinned ? '取消置顶' : '置顶'),
            onTap: () { Navigator.pop(ctx); _togglePin(id); },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('重命名'),
            onTap: () { Navigator.pop(ctx); _showRenameDialog(id, title); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('删除', style: TextStyle(color: AppColors.danger)),
            onTap: () { Navigator.pop(ctx); _confirmDelete(id, title); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showRenameDialog(String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: '输入新标题')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () {
            final t = ctrl.text.trim();
            if (t.isNotEmpty) context.read<ConversationProvider>().rename(id, t);
            Navigator.pop(ctx);
          }, child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除 "$title"？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) _deleteConv(id);
  }

  Widget _emptyState(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textSecondary(b).withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      Text('开始第一段对话吧', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 15)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _newConversation, icon: const Icon(Icons.add), label: const Text('新建对话')),
    ]),
  );

  Widget _errorState(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary(b)),
      const SizedBox(height: 12),
      Text('加载失败', style: TextStyle(color: AppColors.textSecondary(b))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _refresh, child: const Text('重试')),
    ]),
  );
}
