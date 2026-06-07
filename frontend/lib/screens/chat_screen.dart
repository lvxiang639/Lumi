import 'dart:convert' show jsonDecode;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../providers/chat_provider.dart';
import '../services/ws_service.dart';
import '../services/email_service.dart';
import '../services/notes_service.dart';
import '../services/conversation_service.dart';
import '../widgets/character_webview.dart';
import '../widgets/sci_fi_bg.dart';
import '../widgets/assistant_menu.dart';

// ── Palette ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? conversationTitle;

  const ChatScreen({super.key, this.conversationId, this.conversationTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showField = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<ChatProvider>().startConversation(
          conversationId: widget.conversationId,
        );
      } catch (e) { debugPrint('Init: $e'); }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose(); _scrollCtrl.dispose();
    // Don't end conversation here — keep state when navigating back
    super.dispose();
  }

  void _send() {
    final t = _textCtrl.text.trim(); if (t.isEmpty) return;
    _textCtrl.clear(); context.read<ChatProvider>().sendText(t);
    setState(() => _showField = false);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'pdf']);
    if (r == null || r.files.single.path == null) return;
    final p = r.files.single.path!, n = r.files.single.name;
    final ext = n.split('.').last.toLowerCase(), target = ext == 'pdf' ? 'docx' : 'pdf';
    final chat = context.read<ChatProvider>();
    chat.sendText('📎 $n — ${target == 'pdf' ? '转为PDF' : '转为Word'}');
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/tools/convert?target=$target');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $tok'
        ..files.add(await http.MultipartFile.fromPath('file', p));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        chat.sendText('✅ ${d['target_name'] ?? '完成'}');
      } else { chat.sendText('❌ 转换失败'); }
    } catch (_) { chat.sendText('❌ 出错'); }
  }

  void _showAssistantMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AssistantMenu(
        conversationId: widget.conversationId,
        onEmailSummary: _onEmailSummary,
        onNotes: _onSaveNote,
        onExtractSummary: _onExtractSummary,
      ),
    );
  }

  Future<void> _onEmailSummary() async {
    final chat = context.read<ChatProvider>();
    final convId = chat.conversationId;
    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先发送一条消息'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
      return;
    }
    // Show processing message in chat
    chat.sendText('📧 正在处理邮件发送...');
    try {
      final emailService = EmailService();
      await emailService.sendEmailSummary(convId);
      emailService.dispose();
      chat.sendText('✅ 对话总结已发送到邮箱');
    } catch (e) {
      chat.sendText('❌ 邮件发送失败，请检查邮箱设置');
    }
  }

  Future<void> _onSaveNote() async {
    final chat = context.read<ChatProvider>();
    final msgs = chat.messages;
    if (msgs.isEmpty) return;
    try {
      final notesService = NotesService();
      final content = msgs.last.content;
      await notesService.createNote({
        'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}',
        'content': content,
        'note_type': 'note',
      });
      notesService.dispose();
      chat.sendText('📝 已保存为笔记');
    } catch (e) {
      chat.sendText('❌ 笔记保存失败');
    }
  }

  Future<void> _onExtractSummary() async {
    final chat = context.read<ChatProvider>();
    final convId = chat.conversationId;
    if (convId == null) return;
    chat.sendText('📋 AI 正在提炼对话摘要...');
    try {
      final svc = ConversationService();
      final summary = await svc.summarizeConversation(convId);
      svc.dispose();
      if (summary.isNotEmpty) {
        chat.sendText('📋 对话摘要:\n$summary');
      } else {
        chat.sendText('❌ 摘要生成失败');
      }
    } catch (e) {
      chat.sendText('❌ 摘要生成失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (ctx, chat, _) {
        final msgs = chat.messages;
        final streaming = chat.streamingText;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        });

        return Stack(children: [
          const SciFiBackground(),
          Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            appBar: _bar(chat),
            body: Stack(children: [
              // Messages — full screen
              if (msgs.isNotEmpty || streaming.isNotEmpty)
                Positioned(top: 0, left: 0, right: 0, bottom: 90,
                  child: _Msgs(msgs: msgs, streaming: streaming, ctrl: _scrollCtrl),
                ),
              // Empty state for new conversations with no history
              if (msgs.isEmpty && streaming.isEmpty && chat.historyLoaded)
                Positioned(top: 0, left: 0, right: 0, bottom: 90,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48,
                          color: _textDim.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('开始一段新对话吧', style: TextStyle(
                          color: _textDim.withValues(alpha: 0.5), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              // Character — Q pet, bottom-right (simplified: no mouth animation)
              if (chat.isProcessing || chat.streamingText.isNotEmpty)
                Positioned(bottom: 68, right: 0,
                  width: 130, height: 200,
                  child: CharacterWebView(
                    animState: 'talking',
                    emotion: chat.emotion,
                    emotionIntensity: chat.emotionIntensity,
                  ),
                ),
              if (!chat.isProcessing && chat.streamingText.isEmpty)
                Positioned(bottom: 68, right: 0,
                  width: 130, height: 200,
                  child: CharacterWebView(
                    animState: 'idle',
                    emotion: chat.emotion,
                    emotionIntensity: chat.emotionIntensity,
                  ),
                ),
              if (chat.wsState == WsState.connecting)
                const Positioned(top: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: _accent)),
            ]),
          ),
          // Input bar
          Positioned(bottom: 22, left: 20, right: 20,
            child: _InputBar(ctrl: _textCtrl, showField: _showField,
              onToggle: () => setState(() => _showField = !_showField),
              onSend: _send, onFile: _pickFile),
          ),
        ]);
      },
    );
  }

  PreferredSizeWidget _bar(ChatProvider chat) {
    final title = widget.conversationTitle ?? '新对话';
    return PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(
            color: chat.wsState == WsState.connected ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: (chat.wsState == WsState.connected ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
      actions: [
        // Assistant button (replaces old 工具 button)
        Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(
          onTap: _showAssistantMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, color: _accent, size: 14),
              SizedBox(width: 4),
              Text('助手', style: TextStyle(color: _accentWarm, fontSize: 11)),
            ]),
          ),
        )),
      ],
    ));
  }
}

// ── Message Panel ──

class _Msgs extends StatelessWidget {
  final List msgs;
  final String streaming;
  final ScrollController ctrl;
  const _Msgs({required this.msgs, required this.streaming, required this.ctrl});

  void _showMessageMenu(BuildContext ctx, String content) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 4), width: 32, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.copy, color: _accent),
              title: const Text('复制', style: TextStyle(color: _textMain)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined, color: Color(0xFF10B981)),
              title: const Text('记笔记', style: TextStyle(color: _textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _saveMessageAsNote(ctx, content);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMessageAsNote(BuildContext ctx, String content) async {
    try {
      final notesService = NotesService();
      await notesService.createNote({
        'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}',
        'content': content,
        'note_type': 'note',
      });
      notesService.dispose();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('已保存为笔记 📝'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: msgs.length + (streaming.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < msgs.length) return _bubble(ctx, msgs[i]);
        return _streamBubble(ctx, streaming);
      },
    );
  }

  Widget _bubble(BuildContext ctx, dynamic m) {
    final isUser = m.role == 'user';
    final content = (m.content ?? '').toString();
    final label = isUser ? '你' : '灵犀';

    // AI message → left-aligned (avatar on left)
    // User message → right-aligned (avatar on right)
    final aiColor = [_accent, const Color(0xFF6366F1)];
    final userColor = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
    final gradient = isUser ? userColor : aiColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(ctx, content),
        child: isUser
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _glass,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(content, style: const TextStyle(color: _textMain, fontSize: 13, height: 1.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _glass,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(content, style: const TextStyle(color: _textMain, fontSize: 13, height: 1.5)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _streamBubble(BuildContext ctx, String text) {
    // Streaming is always AI (灵犀), so it's left-aligned
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32, margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('灵', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Flexible(child: Text(text, style: const TextStyle(color: _textMain, fontSize: 13, height: 1.5))),
            const SizedBox(width: 6),
            const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent)),
          ]),
        ),
      ),
    ]);
  }
}

// ── Input Bar ──

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool showField;
  final VoidCallback onToggle, onSend, onFile;
  const _InputBar({required this.ctrl, required this.showField, required this.onToggle, required this.onSend, required this.onFile});

  @override
  Widget build(BuildContext ctx) {
    return Row(children: [
      if (showField) ...[
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(color: _surface.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(21), border: Border.all(color: _accent.withValues(alpha: 0.2))),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(child: Material(color: Colors.transparent,
                child: TextField(controller: ctrl, autofocus: true,
                    style: const TextStyle(color: _textMain, fontSize: 14),
                    decoration: const InputDecoration(hintText: '输入...', hintStyle: TextStyle(color: _textDim), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                    onSubmitted: (_) => onSend()))),
              GestureDetector(onTap: onSend, child: const Icon(Icons.send_rounded, color: _accent, size: 18)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
      ],
      _btn(Icons.chat_bubble_outline, showField ? Icons.close : null, onToggle, 40),
      const SizedBox(width: 8),
      _btn(Icons.attach_file, null, onFile, 40),
    ]);
  }

  Widget _btn(IconData icon, IconData? alt, VoidCallback onTap, double size) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: _surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(size / 2), border: Border.all(color: _border)),
        child: Icon(alt ?? icon, color: alt != null ? _accentWarm : _textDim, size: size * 0.48),
      ),
    );
  }
}