import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final Message? message;
  final bool isStreaming;
  final String streamingText;

  const ChatBubble({super.key, this.message, this.isStreaming = false, this.streamingText = ''});

  @override
  Widget build(BuildContext context) {
    final isUser = message?.role == 'user';
    final text = isStreaming ? streamingText : (message?.content ?? '');
    if (text.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isUser ? Colors.indigo.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: isStreaming
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(text)),
                  const SizedBox(width: 4),
                  const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1)),
                ])
              : SelectableText(text),
        ),
      ),
    );
  }
}
