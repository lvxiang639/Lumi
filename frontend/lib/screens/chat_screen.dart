import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
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
            title: const Text('对话'),
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const VoiceRecordButton(),
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
