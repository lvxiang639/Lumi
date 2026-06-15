import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';

class KnowledgeChatPage extends StatefulWidget {
  final String kbId;
  final String kbTitle;

  const KnowledgeChatPage({super.key, required this.kbId, required this.kbTitle});

  @override
  State<KnowledgeChatPage> createState() => _KnowledgeChatPageState();
}

class _KnowledgeChatPageState extends State<KnowledgeChatPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final resp = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/knowledge/${widget.kbId}/messages'),
        headers: {'Authorization': 'Bearer $tok'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final msgs = (data['messages'] as List?) ?? [];
        setState(() {
          _msgs.addAll(msgs.map((m) => _ChatMsg(
            role: m['role'] as String? ?? 'user',
            content: m['content'] as String? ?? '',
            sources: (m['sources'] as List?)?.cast<String>() ?? [],
          )));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_ChatMsg(role: 'user', content: query));
      _loading = true;
    });
    _scrollDown();

    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/knowledge/${widget.kbId}/chat');
      final resp = await http.post(uri,
        headers: {'Authorization': 'Bearer $tok'},
        body: {'query': query},
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final answer = data['answer'] as String? ?? '';
        final sources = (data['sources'] as List?)?.cast<String>() ?? [];
        setState(() {
          _msgs.add(_ChatMsg(role: 'assistant', content: answer, sources: sources));
          _loading = false;
        });
      } else {
        setState(() {
          _msgs.add(_ChatMsg(role: 'assistant', content: '回答失败，请重试'));
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _msgs.add(_ChatMsg(role: 'assistant', content: '请求失败: $e'));
        _loading = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.hasContentDimensions) {
        final pos = _scrollCtrl.position;
        if (pos.maxScrollExtent - pos.pixels < 200) {
          _scrollCtrl.jumpTo(pos.maxScrollExtent);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.text(b)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.kbTitle, style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.bg(b),
        elevation: 0,
      ),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? _emptyHint(b)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _msgs.length + (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i < _msgs.length) return _bubble(_msgs[i], b);
                    return _loadingBubble(b);
                  },
                ),
        ),
        _inputBar(b),
      ]),
    );
  }

  Widget _emptyHint(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.chat_outlined, color: Color(0xFF8B5CF6), size: 28)),
      const SizedBox(height: 14),
      Text('向文档提问', style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('AI 将基于文档内容回答', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
    ]),
  );

  Widget _bubble(_ChatMsg msg, Brightness b) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.bubbleUser(b) : AppColors.bubbleAi(b),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: AppColors.border(b)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            SelectableText(msg.content, style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)),
            // Source citations
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text('📖 参考来源', style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...msg.sources.asMap().entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.5), width: 3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.w700))),
                    ),
                    Expanded(child: Text(e.value, style: TextStyle(color: AppColors.text(b).withValues(alpha: 0.8), fontSize: 12, height: 1.5))),
                  ]),
                );
              }),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _loadingBubble(Brightness b) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bubbleAi(b),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
          border: Border.all(color: AppColors.border(b)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary(b))),
          const SizedBox(width: 10),
          Text('思考中...', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
        ]),
      ),
    ),
  );

  Widget _inputBar(Brightness b) {
    final hasText = _ctrl.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        border: Border(top: BorderSide(color: AppColors.border(b))),
      ),
      child: Row(children: [
        Expanded(child: Container(
          constraints: const BoxConstraints(minHeight: 44, maxHeight: 100),
          decoration: BoxDecoration(
            color: b == Brightness.light ? Colors.white : AppColors.darkCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border(b)),
          ),
          child: TextField(
            controller: _ctrl,
            minLines: 1, maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            style: TextStyle(color: AppColors.text(b), fontSize: 15),
            decoration: InputDecoration(
              hintText: '基于文档提问...',
              hintStyle: TextStyle(color: AppColors.textSecondary(b), fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (_) => setState(() {}),
          ),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: hasText ? _ask : null,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: hasText ? AppColors.accent : AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.send_rounded, color: hasText ? Colors.white : AppColors.accent.withValues(alpha: 0.4), size: 20),
          ),
        ),
      ]),
    );
  }
}

class _ChatMsg {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> sources;

  _ChatMsg({required this.role, required this.content, this.sources = const []});
}
