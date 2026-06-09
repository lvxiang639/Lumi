import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool showField;
  final VoidCallback onToggle, onSend, onFile, onVoice;
  final Brightness brightness;
  final bool listening;

  const ChatInputBar({
    super.key,
    required this.ctrl, required this.showField,
    required this.onToggle, required this.onSend, required this.onFile,
    required this.onVoice, required this.brightness,
    this.listening = false,
  });

  @override
  Widget build(BuildContext ctx) {
    final hasText = ctrl.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        border: Border(top: BorderSide(color: AppColors.border(brightness))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Voice
        GestureDetector(
          onTap: onVoice,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: listening ? AppColors.danger.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? AppColors.danger : AppColors.accent, size: 20),
          ),
        ),
        const SizedBox(width: 6),
        // Text field
        Expanded(child: Container(
          constraints: const BoxConstraints(minHeight: 36, maxHeight: 100),
          decoration: BoxDecoration(
            color: brightness == Brightness.light ? Colors.white : AppColors.darkCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: TextField(
            controller: ctrl, autofocus: showField,
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send,
            onChanged: (_) => (ctx as Element).markNeedsBuild(),
            onSubmitted: (_) => onSend(),
            style: TextStyle(color: AppColors.text(brightness), fontSize: 15),
            decoration: InputDecoration(
              hintText: showField ? '输入消息...' : '语音输入',
              hintStyle: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        )),
        const SizedBox(width: 6),
        // Send / Attach
        GestureDetector(
          onTap: hasText ? onSend : onFile,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: hasText ? AppColors.accent : AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(hasText ? Icons.send_rounded : Icons.add, color: hasText ? Colors.white : AppColors.accent, size: 18),
          ),
        ),
      ]),
    );
  }
}
