import 'dart:convert' show jsonDecode;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../providers/chat_provider.dart';
import '../providers/character_provider.dart';
import '../services/ws_service.dart';
import '../widgets/character_webview.dart';
import '../widgets/sci_fi_bg.dart';
import '../widgets/tools_panel.dart';
import '../widgets/voice_record_button.dart';

// ── Palette ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

const _defaultCharacterName = '小灵';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showField = false;
  bool _showTools = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<ChatProvider>().startConversation();
        context.read<CharacterProvider>().loadConfig();
      } catch (e) { debugPrint('Init: $e'); }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose(); _scrollCtrl.dispose(); super.dispose();
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

  void _showCharacterMenu() {
    final prov = context.read<CharacterProvider>();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      builder: (ctx) => _CharSheet(provider: prov),
    );
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
              // Character — Q pet, bottom-right
              Positioned(bottom: 68, right: 0,
                width: 130, height: 200,
                child: CharacterWebView(mouthOpen: chat.mouthOpen, animState: chat.animState.name,
                    emotion: chat.emotion, emotionIntensity: chat.emotionIntensity),
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
          // Tools overlay
          if (_showTools)
            Positioned.fill(child: ToolsPanel(onClose: () => setState(() => _showTools = false))),
        ]);
      },
    );
  }

  PreferredSizeWidget _bar(ChatProvider chat) {
    return PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      title: Row(children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(
            color: chat.wsState == WsState.connected ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: (chat.wsState == WsState.connected ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 10),
        const Text('灵犀', style: TextStyle(color: _textDim, fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
      actions: [
        // Tools pill
        Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(
          onTap: () => setState(() => _showTools = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.grid_view_rounded, color: _accent, size: 15),
              SizedBox(width: 4),
              Text('工具', style: TextStyle(color: _accentWarm, fontSize: 11)),
            ]),
          ),
        )),
        IconButton(icon: const Icon(Icons.person_outline, color: _textDim, size: 20), tooltip: '角色', onPressed: _showCharacterMenu),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isUser ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)] : [_accent, const Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
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
        ]),
      ),
    );
  }

  Widget _streamBubble(BuildContext ctx, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32, margin: const EdgeInsets.only(top: 2, right: 8),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('灵', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
      ),
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
      const SizedBox(width: 8),
      const _VoiceBtn(),
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

// ── Voice Button ──

class _VoiceBtn extends StatefulWidget {
  const _VoiceBtn();
  @override
  State<_VoiceBtn> createState() => _VoiceBtnState();
}

class _VoiceBtnState extends State<_VoiceBtn> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return AnimatedBuilder(animation: _pulse, builder: (_, __) {
      return Stack(alignment: Alignment.center, children: [
        Transform.scale(scale: 1 + _pulse.value * 0.12,
          child: Container(width: 58, height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2)]))),
        VoiceRecordButton(onAudioReady: (b64) {
          if (context.mounted) ctx.read<ChatProvider>().sendVoice(b64);
        }),
      ]);
    });
  }
}

// ── Character Sheet ──

class _CharSheet extends StatelessWidget {
  final CharacterProvider provider;
  const _CharSheet({required this.provider});

  @override
  Widget build(BuildContext ctx) {
    final cfg = provider.config;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, -8))],
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 32, height: 3, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
          if (provider.loading)
            const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _accent))
          else if (cfg == null)
            Padding(padding: const EdgeInsets.all(32), child: Column(children: [
              const Icon(Icons.person_outline, size: 44, color: _textDim),
              const SizedBox(height: 12),
              const Text('未初始化', style: TextStyle(color: _textDim)),
              const SizedBox(height: 16),
              SizedBox(width: 180,
                child: ElevatedButton(
                  onPressed: () => provider.initCharacter(_defaultCharacterName).then((_) { if (ctx.mounted) Navigator.pop(ctx); }),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('初始化角色'),
                ),
              ),
            ]))
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 48, height: 48,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.person, color: Colors.white, size: 26)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cfg.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textMain)),
                      Text('${cfg.outfitName ?? "默认"} · ${cfg.voicePackName ?? "默认"}', style: const TextStyle(fontSize: 11, color: _textDim)),
                    ]),
                  ]),
                  const SizedBox(height: 20),
                  _sec('服装', Icons.checkroom_outlined),
                  ...provider.outfits.map((o) => _card(o['name'] as String? ?? '', o['equipped'] == true, () => provider.equip('outfit', o['id'] as String), '穿上')),
                  const SizedBox(height: 18),
                  _sec('声音', Icons.mic_outlined),
                  ...provider.voices.map((v) => _card(v['name'] as String? ?? '', v['equipped'] == true, () => provider.equip('voice_pack', v['id'] as String), '使用', sub: v['type'] as String?)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sec(String t, IconData i) => Row(children: [
    Icon(i, size: 14, color: _accentWarm), const SizedBox(width: 6),
    Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accentWarm)),
  ]);

  Widget _card(String name, bool active, VoidCallback onTap, String label, {String? sub}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5, top: 6),
      decoration: BoxDecoration(color: active ? _accent.withValues(alpha: 0.1) : _glass, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: _textMain, fontSize: 13)),
        subtitle: sub != null ? Text(sub, style: const TextStyle(fontSize: 11, color: _textDim)) : null,
        dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        trailing: active
            ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 14, color: _accent), SizedBox(width: 4), Text('使用中', style: TextStyle(fontSize: 11, color: _accent))])
            : TextButton(onPressed: onTap, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(label, style: const TextStyle(fontSize: 11, color: _accentWarm))),
      ),
    );
  }
}
