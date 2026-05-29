import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/character_provider.dart';
import '../services/ws_service.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/character_view.dart';
import '../widgets/tools_panel.dart';
import '../widgets/sci_fi_bg.dart';

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
  bool _showTextField = false;

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

  void _openTools() {
    Scaffold.of(context).openEndDrawer();
  }

  void _showCharacterMenu() {
    final provider = context.read<CharacterProvider>();
    final config = provider.config;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(chat),
              endDrawer: const ToolsPanel(),
              body: Stack(
                children: [
                  // ---- character (upper 60%) ----
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).size.height * 0.58,
                    child: CharacterView(
                      mouthOpen: chat.mouthOpen,
                      animState: chat.animState.name,
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
            color: const Color(0xFF141832).withValues(alpha: 0.75),
            border: Border.all(
              color: const Color(0xFF7C8FFF).withValues(alpha: 0.2),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isUser
                ? const Color(0xFF7C8FFF).withValues(alpha: 0.3)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.content ?? '',
            style: TextStyle(
              color: isUser ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingMessage(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF7C8FFF),
                ),
              ),
            ],
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

  const _FloatingInputBar({
    required this.textController,
    required this.showTextField,
    required this.onToggleText,
    required this.onSend,
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
                color: const Color(0xFF141832).withValues(alpha: 0.85),
                border: Border.all(
                  color: const Color(0xFF7C8FFF).withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
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
          color: const Color(0xFF141832).withValues(alpha: 0.85),
          border: Border.all(
            color: const Color(0xFF7C8FFF).withValues(alpha: 0.3),
          ),
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
                  border: Border.all(
                    color: const Color(0xFF7C8FFF).withValues(alpha: 0.3),
                    width: 2,
                  ),
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
        color: const Color(0xFF141832).withValues(alpha: 0.8),
        border: Border.all(
          color: const Color(0xFF7C8FFF).withValues(alpha: 0.3),
        ),
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

// ---- character bottom sheet (from original) ----

class _CharacterSheet extends StatelessWidget {
  final CharacterProvider provider;
  final dynamic config;

  const _CharacterSheet({required this.provider, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFF7C8FFF).withValues(alpha: 0.2),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: provider.loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C8FFF)))
              : config == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('尚未初始化角色',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            provider.initCharacter(_defaultCharacterName).then((_) {
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C8FFF),
                          ),
                          child: const Text('初始化默认角色'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Color(0xFF7C8FFF),
                                  child: Icon(Icons.person,
                                      size: 36, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(config.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              Text(
                                  '服装: ${config.outfitName ?? "默认"} | 声音: ${config.voicePackName ?? "默认"}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white38)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('服装',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        ...provider.outfits.map((o) => _itemTile(
                              context,
                              o['name'] as String? ?? '',
                              o['equipped'] == true,
                              () => provider.equip('outfit', o['id'] as String),
                              '穿上',
                            )),
                        const Divider(color: Colors.white12),
                        const Text('声音',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        ...provider.voices.map((v) => _itemTile(
                              context,
                              v['name'] as String? ?? '',
                              v['equipped'] == true,
                              () => provider.equip(
                                  'voice_pack', v['id'] as String),
                              '使用',
                              subtitle:
                                  v['type'] as String?,
                            )),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _itemTile(
    BuildContext context,
    String name,
    bool equipped,
    VoidCallback onTap,
    String actionLabel, {
    String? subtitle,
  }) {
    return ListTile(
      title: Text(name, style: const TextStyle(color: Colors.white70)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white38))
          : null,
      dense: true,
      trailing: equipped
          ? const Text('使用中',
              style: TextStyle(fontSize: 12, color: Colors.white30))
          : TextButton(
              onPressed: onTap,
              child: Text(actionLabel,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF7C8FFF))),
            ),
    );
  }
}
