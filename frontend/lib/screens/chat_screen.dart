import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/character_provider.dart';
import '../services/ws_service.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/character_webview.dart';
import '../widgets/tools_panel.dart';
import '../widgets/sci_fi_bg.dart';
import '../services/api_client.dart';
import '../config.dart';
import 'dart:convert' show jsonDecode;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const _defaultCharacterName = '小灵';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _msgNotifier = ValueNotifier<int>(0);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showTextField = false;
  bool _showToolsPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<ChatProvider>().startConversation();
        context.read<CharacterProvider>().loadConfig();
      } catch (e) {
        debugPrint('Init error: $e');
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _msgNotifier.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendText(text);
    _showTextField = false;
    setState(() {});
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();
    final target = ext == 'pdf' ? 'docx' : 'pdf';

    if (!mounted) return;
    // Show file attachment in chat
    final chat = context.read<ChatProvider>();
    final text = target == 'pdf' ? '帮我把这个转成PDF' : '帮我把这个转成Word';
    chat.sendText('📎 上传: $name — $text');

    // Upload + convert via HTTP
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/convert?target=$target');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', path));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final outName = data['target_name'] as String? ?? 'output';
        chat.sendText('✅ 转换完成: $outName\n可到工具 → 📄 文件处理 中下载');
      } else {
        chat.sendText('❌ 转换失败，请重试');
      }
    } catch (e) {
      chat.sendText('❌ 转换出错: $e');
    }
  }

  void _openTools() {
    setState(() => _showToolsPanel = true);
  }

  Future<void> _emailSummary() async {
    final convId = context.read<ChatProvider>().conversationId;
    if (convId == null) {
      _showSnack('请先开始对话');
      return;
    }

    try {
      final api = ApiClient();
      await api.post('/api/conversations/$convId/email-summary');
      if (mounted) _showSnack('对话摘要已发送到你的邮箱');
    } on ApiException catch (e) {
      if (e.statusCode == 400 && e.body.contains('邮箱')) {
        if (mounted) _showEmailSetup();
      } else {
        if (mounted) _showSnack('发送失败，请稍后再试');
      }
    } catch (_) {
      if (mounted) _showSnack('发送失败，请稍后再试');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF141832),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEmailSetup() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text('设置邮箱',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: '输入你的邮箱地址',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF7C8FFF)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF7C8FFF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              try {
                final api = ApiClient();
                await api.put(
                    '/api/auth/profile', body: {'email': email});
                if (ctx.mounted) Navigator.pop(ctx);
                // Retry the email summary
                await _emailSummary();
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('保存失败')),
                  );
                }
              }
            },
            child: const Text('保存并发送',
                style: TextStyle(color: Color(0xFF7C8FFF))),
          ),
        ],
      ),
    );
  }

  void _showCharacterMenu() {
    final provider = context.read<CharacterProvider>();
    final config = provider.config;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      builder: (ctx) => _CharacterSheet(provider: provider, config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final messages = chat.messages;
        final hasStreaming = chat.streamingText.isNotEmpty;

        // Auto-scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        return Stack(
          children: [
            // ---- sci-fi background ----
            const SciFiBackground(),

            // ---- main layout ----
            Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(chat),
              body: Stack(
                children: [
                  // ---- character (upper 60%) ----
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).size.height * 0.58,
                    child: CharacterWebView(
                      mouthOpen: chat.mouthOpen,
                      animState: chat.animState.name,
                      emotion: chat.emotion,
                      emotionIntensity: chat.emotionIntensity,
                    ),
                  ),

                  // ---- chat panel (glass, bottom-left) ----
                  if (messages.isNotEmpty || hasStreaming)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 120,
                      height: MediaQuery.of(context).size.height * 0.28,
                      child: _GlassChatPanel(
                        messages: messages,
                        streamingText: chat.streamingText,
                        hasStreaming: hasStreaming,
                        scrollController: _scrollController,
                      ),
                    ),

                  // ---- status bar ----
                  if (chat.wsState == WsState.connecting)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        color: Color(0xFF7C8FFF),
                      ),
                    ),

                  if (chat.isTtsPlaying)
                    Positioned(
                      bottom: 110,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _TtsIndicator(onStop: chat.stopTts),
                      ),
                    ),
                ],
              ),
            ),

            // ---- floating input cluster (bottom) ----
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: _FloatingInputBar(
                textController: _textController,
                showTextField: _showTextField,
                onToggleText: () {
                  setState(() => _showTextField = !_showTextField);
                },
                onSend: _sendText,
                onPickFile: _pickAndSendFile,
              ),
            ),

            // ---- tools panel overlay ----
            if (_showToolsPanel)
              Positioned.fill(
                child: ToolsPanel(
                  onClose: () => setState(() => _showToolsPanel = false),
                ),
              ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ChatProvider chat) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: chat.wsState == WsState.connected
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: chat.wsState == WsState.connected
                        ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                        : const Color(0xFFF87171).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text('灵犀',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined, color: Colors.white54),
            tooltip: '发送对话摘要到邮箱',
            onPressed: () => _emailSummary(),
          ),
          IconButton(
            icon: const Icon(Icons.build_outlined, color: Colors.white54),
            tooltip: '工具',
            onPressed: _openTools,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white54),
            tooltip: '角色',
            onPressed: _showCharacterMenu,
          ),
        ],
      ),
    );
  }
}

// ---- glass chat panel ----

class _GlassChatPanel extends StatelessWidget {
  final List<dynamic> messages;
  final String streamingText;
  final bool hasStreaming;
  final ScrollController scrollController;

  const _GlassChatPanel({
    required this.messages,
    required this.streamingText,
    required this.hasStreaming,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141832).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(10),
            itemCount: messages.length + (hasStreaming ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i < messages.length) {
                return _buildMessage(ctx, messages[i]);
              }
              return _buildStreamingMessage(ctx, streamingText);
            },
          ),
        ),
    );
  }

  Widget _buildMessage(BuildContext context, dynamic msg) {
    final isUser = msg.role == 'user';
    final prefix = isUser ? '你: ' : '灵犀: ';
    final prefixColor = isUser
        ? const Color(0xFF60A5FA)
        : const Color(0xFFA78BFA);
    final textColor = isUser
        ? const Color(0xFFCBD5E1)
        : const Color(0xFFE2E8F0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: prefix,
                  style: TextStyle(
                    color: prefixColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: msg.content ?? '',
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingMessage(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '灵犀: ',
                  style: TextStyle(
                    color: Color(0xFFA78BFA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                ),
                const WidgetSpan(
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF7C8FFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- floating input bar ----

class _FloatingInputBar extends StatelessWidget {
  final TextEditingController textController;
  final bool showTextField;
  final VoidCallback onToggleText;
  final VoidCallback onSend;
  final VoidCallback onPickFile;

  const _FloatingInputBar({
    required this.textController,
    required this.showTextField,
    required this.onToggleText,
    required this.onSend,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // text input area (right side, expands)
        if (showTextField) ...[
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF141832).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: textController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          hintStyle:
                              TextStyle(color: Colors.white30, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSend,
                    child: const Icon(Icons.send_rounded,
                        color: Color(0xFF7C8FFF), size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // text toggle button
        _FloatingBtn(
          icon: showTextField ? Icons.close : Icons.chat_bubble_outline,
          size: 44,
          onTap: onToggleText,
        ),
        const SizedBox(width: 12),

        // file upload button
        _FloatingBtn(
          icon: Icons.attach_file,
          size: 44,
          onTap: onPickFile,
        ),
        const SizedBox(width: 12),

        // voice record button (large)
        const SizedBox(
          width: 64,
          height: 64,
          child: _GlowVoiceButton(),
        ),
      ],
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _FloatingBtn({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF141832).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Icon(icon, color: Colors.white70, size: size * 0.45),
      ),
    );
  }
}

// ---- glow voice button ----

class _GlowVoiceButton extends StatefulWidget {
  const _GlowVoiceButton();

  @override
  State<_GlowVoiceButton> createState() => _GlowVoiceButtonState();
}

class _GlowVoiceButtonState extends State<_GlowVoiceButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = 1.0 + _pulseCtrl.value * 0.1;
        return Stack(
          alignment: Alignment.center,
          children: [
            // outer glow ring
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C8FFF).withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            // inner button
            VoiceRecordButton(
              onAudioReady: (base64) {
                if (context.mounted) {
                  context.read<ChatProvider>().sendVoice(base64);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// ---- TTS indicator ----

class _TtsIndicator extends StatelessWidget {
  final VoidCallback onStop;

  const _TtsIndicator({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141832).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, size: 16, color: Color(0xFF7C8FFF)),
          const SizedBox(width: 6),
          const Text('语音播报中…',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onStop,
            child: const Icon(Icons.stop, size: 16, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

// ---- character sheet (redesigned) ----

class _CharacterSheet extends StatelessWidget {
  final CharacterProvider provider;
  final dynamic config;

  const _CharacterSheet({required this.provider, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141832),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C8FFF).withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (provider.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C8FFF)),
                ),
              )
            else if (config == null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline,
                        size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text('尚未初始化角色',
                        style: TextStyle(fontSize: 16, color: Colors.white54)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          provider
                              .initCharacter(_defaultCharacterName)
                              .then((_) {
                            if (context.mounted) Navigator.pop(context);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C8FFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('初始化默认角色'),
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- header ---
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C8FFF), Color(0xFFA78BFA)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.person,
                                size: 30, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(config.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(
                                '服装: ${config.outfitName ?? "默认"}  ·  声音: ${config.voicePackName ?? "默认"}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white38),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- outfits section ---
                      _sectionHeader('服装', Icons.checkroom_outlined),
                      const SizedBox(height: 8),
                      ...provider.outfits.map((o) => _outfitCard(
                            context,
                            o['name'] as String? ?? '',
                            o['equipped'] == true,
                            () =>
                                provider.equip('outfit', o['id'] as String),
                          )),

                      const SizedBox(height: 24),

                      // --- voices section ---
                      _sectionHeader('声音', Icons.mic_outlined),
                      const SizedBox(height: 8),
                      ...provider.voices.map((v) => _voiceCard(
                            context,
                            v['name'] as String? ?? '',
                            v['type'] as String? ?? '',
                            v['equipped'] == true,
                            () => provider.equip(
                                'voice_pack', v['id'] as String),
                          )),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7C8FFF)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA78BFA))),
      ],
    );
  }

  Widget _outfitCard(
      BuildContext context, String name, bool equipped, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: equipped
            ? const Color(0xFF7C8FFF).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        trailing: equipped
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Color(0xFF7C8FFF)),
                  SizedBox(width: 4),
                  Text('使用中',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C8FFF))),
                ],
              )
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('穿上',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C8FFF))),
              ),
      ),
    );
  }

  Widget _voiceCard(
    BuildContext context,
    String name,
    String type,
    bool equipped,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: equipped
            ? const Color(0xFF7C8FFF).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        subtitle:
            Text(type, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        trailing: equipped
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Color(0xFF7C8FFF)),
                  SizedBox(width: 4),
                  Text('使用中',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C8FFF))),
                ],
              )
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('使用',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C8FFF))),
              ),
      ),
    );
  }
}
