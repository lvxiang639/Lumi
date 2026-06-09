import 'dart:convert' show jsonDecode;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../services/ws_service.dart';
import '../services/email_service.dart';
import '../services/notes_service.dart';
import '../services/conversation_service.dart';
import '../widgets/chat_bg_painter.dart';
import '../widgets/assistant_menu.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_input_bar.dart';
import '../services/logger.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// iOS-style slide transition
Route _slideRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
  );
}

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? conversationTitle;
  const ChatScreen(
      {super.key, this.conversationId, this.conversationTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showField = false;
  final _stt = stt.SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversation(
            conversationId: widget.conversationId,
          );
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    context.read<ChatProvider>().sendText(t);
    setState(() => _showField = false);
  }

  Future<void> _startVoice() async {
    AppLogger.voice('按钮点击 listening=$_listening');
    if (_listening) {
      AppLogger.voice('停止监听');
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    try {
      AppLogger.voice('开始初始化...');
      final available = await _stt.initialize(
        onStatus: (status) {
          AppLogger.voice('状态: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          AppLogger.error('语音初始化错误', error);
        },
      );
      AppLogger.voice('初始化结果: $available');
      if (!available) {
        AppLogger.error('语音不可用 — 可能原因: 模拟器不支持 / 无权限 / 无网络');
        _snack('语音识别不可用（模拟器不支持，请用真机测试）');
        return;
      }
      setState(() => _listening = true);
      AppLogger.voice('开始监听 zh_CN...');
      await _stt.listen(
        onResult: (result) {
          AppLogger.voice('识别结果: final=${result.finalResult} text="${result.recognizedWords}"');
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _textCtrl.text = result.recognizedWords;
            setState(() => _listening = false);
            _send();
          }
        },
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          autoPunctuation: true,
        ),
      );
      AppLogger.voice('监听已启动');
    } catch (e, st) {
      AppLogger.error('语音崩溃', e, st);
      setState(() => _listening = false);
      _snack('语音识别出错: $e');
    }
  }

  void _showAssistantMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => AssistantMenu(
        conversationId: widget.conversationId,
        onEmailSummary: _onEmailSummary,
        onNotes: _onSaveNote,
        onExtractSummary: _onExtractSummary,
        onExport: _onExport,
        onShare: _onShare,
        onDiary: _onDiary,
      ),
    );
  }

  Future<void> _onEmailSummary() async {
    final chat = context.read<ChatProvider>();
    if (chat.conversationId == null) {
      _snack('请先发送一条消息');
      return;
    }
    chat.sendText('📧 正在处理邮件发送...');
    try {
      final svc = EmailService();
      await svc.sendEmailSummary(chat.conversationId!);
      svc.dispose();
      chat.sendText('✅ 对话总结已发送到邮箱');
    } catch (_) {
      chat.sendText('❌ 邮件发送失败');
    }
  }

  Future<void> _onSaveNote() async {
    final chat = context.read<ChatProvider>();
    if (chat.messages.isEmpty) return;
    try {
      final svc = NotesService();
      await svc.createNote({
        'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}',
        'content': chat.messages.last.content,
        'note_type': 'note',
      });
      svc.dispose();
      chat.sendText('📝 已保存为笔记');
    } catch (_) {
      chat.sendText('❌ 笔记保存失败');
    }
  }

  Future<void> _onDiary() async {
    final chat = context.read<ChatProvider>();
    final convId = chat.conversationId;
    if (convId == null) { _snack('请先发送一条消息'); return; }
    chat.sendText('📔 正在生成日记...');
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/conversations/$convId/diary');
      final resp = await http.post(uri, headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'});
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        chat.sendText('📔 ${d['content']}');
      } else { chat.sendText('❌ 日记生成失败'); }
    } catch (_) { chat.sendText('❌ 日记生成失败'); }
  }

  void _onShare() {
    final chat = context.read<ChatProvider>();
    final msgs = chat.messages;
    if (msgs.isEmpty) {
      _snack('请先发送消息');
      return;
    }
    // Build share text from last 6 messages
    final recent = msgs.length > 6 ? msgs.sublist(msgs.length - 6) : msgs;
    final buf = StringBuffer();
    buf.writeln('💬 灵犀对话分享');
    buf.writeln('━━━━━━━━━━━━━━');
    for (final m in recent) {
      final role = m.role == 'user' ? '🧑 我' : '🐱 灵犀';
      buf.writeln('$role: ${m.content}');
    }
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln('📱 来自灵犀 AI 伴侣');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const Text('分享对话', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.light ? Colors.white : const Color(0xFF1C2129),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('🐱', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      const Text('灵犀 AI 伴侣', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(),
                    ...recent.map((m) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${m.role == 'user' ? "🧑" : "🐱"} ${m.content}',
                        style: const TextStyle(fontSize: 13, height: 1.5),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: buf.toString()));
                        Navigator.pop(ctx);
                        _snack('已复制分享内容');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('复制文字'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onExport() async {
    final chat = context.read<ChatProvider>();
    final convId = chat.conversationId;
    if (convId == null) {
      _snack('请先发送一条消息');
      return;
    }

    // Show format picker
    final format = await showModalBottomSheet<String>(
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('导出格式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF 文档'),
              subtitle: const Text('适合打印和分享'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Color(0xFF3B82F6)),
              title: const Text('Word 文档'),
              subtitle: const Text('可编辑的 .docx 格式'),
              onTap: () => Navigator.pop(ctx, 'docx'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (format == null) return;
    chat.sendText('📄 正在生成${format == 'pdf' ? 'PDF' : 'Word'}文档...');

    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/conversations/$convId/export?format=$format');
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $tok',
        'Content-Type': 'application/json',
      });
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        chat.sendText('✅ 文档已生成: ${d['target_name']}');
      } else {
        chat.sendText('❌ 导出失败');
      }
    } catch (_) {
      chat.sendText('❌ 导出失败');
    }
  }

  Future<void> _onExtractSummary() async {
    final chat = context.read<ChatProvider>();
    if (chat.conversationId == null) return;
    chat.sendText('📋 正在提炼对话摘要...');
    try {
      final svc = ConversationService();
      final summary = await svc.summarizeConversation(chat.conversationId!);
      svc.dispose();
      if (summary.isNotEmpty) {
        chat.sendText('📋 对话摘要:\n$summary');
      } else {
        chat.sendText('❌ 摘要生成失败');
      }
    } catch (_) {
      chat.sendText('❌ 摘要生成失败');
    }
  }

  String _replyEmoji(String text) {
    if (text.contains('？') || text.contains('吗')) return '💭';
    if (text.contains('好') || text.contains('可以')) return '👌';
    if (text.contains('谢')) return '🙏';
    if (text.contains('不')) return '✋';
    if (text.contains('是')) return '✅';
    return '💬';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx', 'pdf']);
    if (r == null || r.files.single.path == null) return;
    final p = r.files.single.path!, n = r.files.single.name;
    final ext = n.split('.').last.toLowerCase(),
        target = ext == 'pdf' ? 'docx' : 'pdf';
    final chat = context.read<ChatProvider>();
    chat.sendText('📎 $n — ${target == 'pdf' ? '转为PDF' : '转为Word'}');
    try {
      final tok = (await SharedPreferences.getInstance())
              .getString('access_token') ??
          '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/convert?target=$target');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $tok'
        ..files.add(await http.MultipartFile.fromPath('file', p));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        chat.sendText('✅ ${d['target_name'] ?? '完成'}');
      } else {
        chat.sendText('❌ 转换失败');
      }
    } catch (_) {
      chat.sendText('❌ 出错');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Consumer<ChatProvider>(
      builder: (ctx, chat, _) {
        final msgs = chat.messages;
        final streaming = chat.streamingText;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });

        return Scaffold(
          backgroundColor: AppColors.bg(brightness),
          appBar: _bar(chat),
          body: Stack(
            children: [
              // WhatsApp-style dot background
              Positioned.fill(
                child: CustomPaint(
                  painter: ChatBgPainter(
                    dotColor: brightness == Brightness.light
                        ? const Color(0xFF808080)
                        : const Color(0xFF586069),
                  ),
                ),
              ),
              // Messages
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 64,
                child: ChatMessageList(
                  msgs: msgs,
                  streaming: streaming,
                  ctrl: _scrollCtrl,
                  brightness: brightness,
                ),
              ),
              // Empty state
              if (msgs.isEmpty && streaming.isEmpty && chat.historyLoaded)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 64,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48,
                            color: AppColors.textSecondary(brightness)
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('开始一段新对话吧',
                            style: TextStyle(
                                color: AppColors.textSecondary(brightness)
                                    .withValues(alpha: 0.5),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              // Connecting bar
              if (chat.wsState == WsState.connecting)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                      minHeight: 2, backgroundColor: Colors.transparent),
                ),
              // Quick reply chips — elegant pill design
              if (chat.quickReplies.isNotEmpty)
                Positioned(
                  bottom: 56,
                  left: 0, right: 0,
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: chat.quickReplies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final reply = chat.quickReplies[i];
                        final emoji = _replyEmoji(reply);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _textCtrl.text = reply;
                            _send();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: brightness == Brightness.light
                                    ? [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)]
                                    : [const Color(0xFF1E293B), const Color(0xFF1A2332)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(
                                color: brightness == Brightness.light
                                    ? const Color(0xFFCBD5E1).withValues(alpha: 0.6)
                                    : const Color(0xFF334155).withValues(alpha: 0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(reply,
                                  style: TextStyle(
                                    color: AppColors.text(brightness),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          bottomSheet: ChatInputBar(
            ctrl: _textCtrl,
            showField: _showField,
            listening: _listening,
            onVoice: _startVoice,
            onToggle: () => setState(() => _showField = !_showField),
            onSend: _send,
            onFile: _pickFile,
            brightness: brightness,
            emotion: chat.emotion,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _bar(ChatProvider chat) {
    final brightness = Theme.of(context).brightness;
    final title = widget.conversationTitle ?? '小灵';

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new,
            size: 18, color: AppColors.text(brightness)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            child: const Text('🐱', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.text(brightness),
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chat.wsState == WsState.connected
                          ? AppColors.online
                          : AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chat.wsState == WsState.connected ? '在线' : '连接中...',
                    style: TextStyle(
                        color: AppColors.textSecondary(brightness),
                        fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: _showAssistantMenu,
        ),
      ],
    );
  }
}

// ── Messages ──

