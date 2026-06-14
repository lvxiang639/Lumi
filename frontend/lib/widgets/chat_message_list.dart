import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notes_service.dart';
import '../theme/app_colors.dart';
import '../theme/markdown_styles.dart';

class ChatMessageList extends StatelessWidget {
  final List msgs;
  final String streaming;
  final ScrollController ctrl;
  final Brightness brightness;

  const ChatMessageList({
    super.key,
    required this.msgs, required this.streaming,
    required this.ctrl, required this.brightness,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (msgDay == today) return '$h:$m';
    if (msgDay == today.subtract(const Duration(days: 1))) return '昨天 $h:$m';
    return '${dt.month}/${dt.day} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: msgs.length + (streaming.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < msgs.length) {
          final m = msgs[i];
          return Column(children: [
            if (i > 0 && i % 5 == 0 && m.createdAt != null)
              _timeStamp(m.createdAt as DateTime),
            _bubble(ctx, m),
          ]);
        }
        return _streamBubble(ctx, streaming);
      },
    );
  }

  Widget _timeStamp(DateTime dt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(_formatTime(dt),
        style: TextStyle(color: AppColors.textSecondary(brightness).withValues(alpha: 0.6), fontSize: 11)),
  );

  Widget _bubble(BuildContext ctx, dynamic m) {
    final isUser = m.role == 'user';
    final content = (m.content ?? '').toString();
    final createdAt = m.createdAt as DateTime?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onLongPress: () => _showMenu(ctx, content),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser ? AppColors.bubbleUser(brightness) : AppColors.bubbleAi(brightness),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser ? null : Border.all(color: AppColors.border(brightness)),
            ),
            child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (isUser)
                SelectableText(content, style: TextStyle(color: AppColors.text(brightness), fontSize: 15, height: 1.5))
              else
                MarkdownBody(
                  data: content,
                  selectable: true,
                  styleSheet: chatMarkdownStyle(brightness),
                  onTapLink: (text, href, title) {
                    if (href != null) _openLink(ctx, href);
                  },
                ),
              if (createdAt != null) ...[
                const SizedBox(height: 2),
                Text(_formatTime(createdAt), style: TextStyle(color: AppColors.textSecondary(brightness).withValues(alpha: 0.5), fontSize: 10)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _streamBubble(BuildContext ctx, String text) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bubbleAi(brightness),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(text, style: TextStyle(color: AppColors.text(brightness), fontSize: 15, height: 1.5))),
        const SizedBox(width: 6),
        const SizedBox(width: 16, height: 12, child: _TypingDots()),
      ]),
    ),
  );

  void _showMenu(BuildContext ctx, String content) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.copy), title: const Text('复制'),
            onTap: () { Clipboard.setData(ClipboardData(text: content)); Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating)); },
          ),
          ListTile(
            leading: const Icon(Icons.note_alt_outlined), title: const Text('保存为笔记'),
            onTap: () { Navigator.pop(ctx); _saveNote(ctx, content); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _openLink(BuildContext ctx, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('无法打开链接'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _saveNote(BuildContext ctx, String content) async {
    try {
      final svc = NotesService();
      await svc.createNote({'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}', 'content': content, 'note_type': 'note'});
      svc.dispose();
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('已保存为笔记 📝'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('保存失败: $e'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
    }
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (i) => AnimatedBuilder(animation: _ctrl, builder: (_, __) {
      final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
      final scale = 0.4 + 0.6 * (t < 0.5 ? t * 2 : 2 - t * 2);
      return Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: AppColors.textSecondary(Brightness.light).withValues(alpha: 0.4 + 0.6 * scale), shape: BoxShape.circle));
    })),
  );
}
