import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  Future<void> _refresh() async {
    await context.read<ConversationProvider>().load();
  }

  void _newConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    ).then((_) => _refresh());
  }

  void _openConversation(String convId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convId)),
    ).then((_) => _refresh());
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
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.conversations.isEmpty) {
            return _errorState(brightness);
          }
          if (provider.conversations.isEmpty) {
            return _emptyState(brightness);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: provider.conversations.length,
              itemBuilder: (ctx, i) =>
                  _convItem(brightness, provider.conversations[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _convItem(Brightness b, dynamic conv) {
    final id = conv.id as String;
    final title = conv.title as String;
    final lastMessage = conv.lastMessage as String?;
    final updatedAt = conv.updatedAt as DateTime;
    final emoji = ['🐱', '🤖', '📝', '💡', '🎯', '🌟'][id.hashCode.abs() % 6];

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.text(b),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: lastMessage != null && lastMessage.isNotEmpty
            ? Text(
                lastMessage,
                style: TextStyle(
                    color: AppColors.textSecondary(b), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          _formatRelativeTime(updatedAt),
          style:
              TextStyle(color: AppColors.textSecondary(b), fontSize: 11),
        ),
        onTap: () => _openConversation(id),
        onLongPress: () => _showContextMenu(id, title),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showContextMenu(String id, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(id, title);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(id, title);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新标题'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) {
                context.read<ConversationProvider>().rename(id, t);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      context.read<ConversationProvider>().delete(id);
    }
  }

  Widget _emptyState(Brightness b) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 56,
              color: AppColors.textSecondary(b).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('开始第一段对话吧',
              style: TextStyle(
                  color: AppColors.textSecondary(b), fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _newConversation,
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Brightness b) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off,
              size: 48, color: AppColors.textSecondary(b)),
          const SizedBox(height: 12),
          Text('加载失败',
              style: TextStyle(color: AppColors.textSecondary(b))),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }
}
