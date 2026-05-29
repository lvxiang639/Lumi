import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/character_provider.dart';
import '../services/ws_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/character_view.dart';
import '../widgets/tools_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _defaultCharacterName = '小灵';

  final _textController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendText(text);
  }

  void _openTools() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showCharacterMenu() {
    final provider = context.read<CharacterProvider>();
    final config = provider.config;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : config == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('尚未初始化角色',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            provider.initCharacter(_defaultCharacterName).then((_) {
                              if (ctx.mounted) Navigator.pop(ctx);
                            });
                          },
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
                                  backgroundColor: Colors.indigo,
                                  child: Icon(Icons.person,
                                      size: 36, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(config.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  '服装: ${config.outfitName ?? "默认"} | 声音: ${config.voicePackName ?? "默认"}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('服装',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        ...provider.outfits.map((o) => ListTile(
                              title: Text(o['name'] as String? ?? ''),
                              dense: true,
                              trailing: o['equipped'] == true
                                  ? const Text('使用中',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))
                                  : TextButton(
                                      onPressed: () => provider.equip(
                                          'outfit', o['id'] as String),
                                      child: const Text('穿上',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                            )),
                        const Divider(),
                        const Text('声音',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        ...provider.voices.map((v) => ListTile(
                              title: Text(v['name'] as String? ?? ''),
                              subtitle: Text(v['type'] as String? ?? '',
                                  style: const TextStyle(fontSize: 12)),
                              dense: true,
                              trailing: v['equipped'] == true
                                  ? const Text('使用中',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))
                                  : TextButton(
                                      onPressed: () => provider.equip(
                                          'voice_pack', v['id'] as String),
                                      child: const Text('使用',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                            )),
                      ],
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('灵犀'),
            actions: [
              IconButton(
                icon: const Icon(Icons.build_outlined),
                tooltip: '工具',
                onPressed: _openTools,
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: '角色',
                onPressed: _showCharacterMenu,
              ),
            ],
          ),
          endDrawer: const ToolsPanel(),
          body: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.indigo.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: CharacterView(
                    mouthOpen: chat.mouthOpen,
                    animState: chat.animState.name,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chat.messages.length +
                            (chat.streamingText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < chat.messages.length) {
                            return ChatBubble(message: chat.messages[i]);
                          }
                          return ChatBubble(
                              isStreaming: true,
                              streamingText: chat.streamingText);
                        },
                      ),
                    ),
                    if (chat.wsState == WsState.connecting)
                      const LinearProgressIndicator(),
                    if (chat.isTtsPlaying)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volume_up,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('语音播报中…',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: chat.stopTts,
                              icon: const Icon(Icons.stop, size: 16),
                              label: const Text('取消',
                                  style: TextStyle(fontSize: 13)),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            VoiceRecordButton(
                              onAudioReady: (base64) {
                                context
                                    .read<ChatProvider>()
                                    .sendVoice(base64);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                decoration: const InputDecoration(
                                  hintText: '输入消息...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                onSubmitted: (_) => _sendText(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _sendText),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
