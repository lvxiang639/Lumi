import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/conversation_provider.dart';
import '../widgets/sci_fi_bg.dart';
import 'chat_screen.dart';

// ── Palette (matches chat_screen) ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

const _convIcons = ['🚀', '🌌', '🛸', '🤖', '🌟', '💫', '🔭', '🪐', '👾', '⚡', '🌀', '🎯'];
const _convColors = [
  Color(0xFF818CF8), Color(0xFFF0ABFC), Color(0xFF34D399),
  Color(0xFFFBBF24), Color(0xFFF87171), Color(0xFF60A5FA),
  Color(0xFFA78BFA), Color(0xFFFB923C), Color(0xFF2DD4BF),
  Color(0xFFE879F9), Color(0xFF38BDF8), Color(0xFF4ADE80),
];

String _iconFor(String id) => _convIcons[id.hashCode.abs() % _convIcons.length];

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  Future<void> _refresh() async {
    await context.read<ConversationProvider>().load();
  }

  void _startNewConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(),
      ),
    ).then((_) => _refresh());
  }

  void _openConversation(String convId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: convId),
      ),
    ).then((_) => _refresh());
  }

  void _showRenameDialog(String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('重命名对话', style: TextStyle(color: _textMain)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: _textMain),
          decoration: const InputDecoration(
            hintText: '输入新标题',
            hintStyle: TextStyle(color: _textDim),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: _textDim)),
          ),
          TextButton(
            onPressed: () {
              final title = ctrl.text.trim();
              if (title.isNotEmpty) {
                context.read<ConversationProvider>().rename(id, title);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String title, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('删除对话', style: TextStyle(color: _textMain)),
        content: Text('确定删除 "$title"？此操作不可恢复。', style: const TextStyle(color: _textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: _textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      return context.read<ConversationProvider>().delete(id);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _appBar(),
      body: Consumer<ConversationProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          if (provider.error != null && provider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: _textDim),
                  const SizedBox(height: 12),
                  Text('加载失败', style: TextStyle(color: _textDim)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    style: ElevatedButton.styleFrom(backgroundColor: _accent),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (provider.conversations.isEmpty) {
            return _emptyState();
          }
          return RefreshIndicator(
            color: _accent,
            backgroundColor: _surface,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: provider.conversations.length,
              itemBuilder: (ctx, i) => _convCard(provider.conversations[i]),
            ),
          );
        },
      ),
      floatingActionButton: _fab(),
    );
  }

  PreferredSizeWidget _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('灵犀',
          style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _fab() {
    return FloatingActionButton(
      onPressed: _startNewConversation,
      backgroundColor: _accent,
      child: const Icon(Icons.edit_outlined, color: Colors.white),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: _textDim.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('还没有对话', style: TextStyle(color: _textDim, fontSize: 16)),
          const SizedBox(height: 8),
          Text('点击右下角 ✏️ 开始聊天', style: TextStyle(color: _textDim.withValues(alpha: 0.6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _convCard(dynamic conv) {
    final id = conv.id as String;
    final title = conv.title as String;
    final lastMessage = conv.lastMessage as String?;
    final updatedAt = conv.updatedAt as DateTime;
    final icon = _iconFor(id);
    // Determine a gradient color pair from the icon index
    final colorIdx = id.hashCode.abs() % _convColors.length;
    final color = _convColors[colorIdx];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _openConversation(id),
        onLongPress: () => _showContextMenu(id, title, title),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              // Sci-fi icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastMessage != null && lastMessage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        style: TextStyle(color: _textDim.withValues(alpha: 0.7), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time
              Text(
                _formatRelativeTime(updatedAt),
                style: TextStyle(color: _textDim.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(String id, String title, String displayTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(displayTitle, style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const Divider(color: _border, height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _accent),
              title: const Text('重命名', style: TextStyle(color: _textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(id, title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              title: const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(displayTitle, id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
}