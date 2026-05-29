import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/ws_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/live2d_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversation();
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('对话'),
                if (chat.wsState == WsState.connecting) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  chat.endConversation();
                  chat.startConversation();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 200, child: Live2DView()),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chat.messages.length + (chat.streamingText.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i < chat.messages.length) {
                      return ChatBubble(message: chat.messages[i]);
                    }
                    return ChatBubble(isStreaming: true, streamingText: chat.streamingText);
                  },
                ),
              ),
              if (chat.isProcessing)
                const LinearProgressIndicator()
              else if (chat.currentSkill != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Chip(label: Text('执行: ${chat.currentSkill}')),
                ),
              if (chat.isTtsPlaying)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.volume_up, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('语音播报中…', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          context.read<ChatProvider>().stopTts();
                        },
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('取消', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                          context.read<ChatProvider>().sendVoice(base64);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: '输入消息...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
