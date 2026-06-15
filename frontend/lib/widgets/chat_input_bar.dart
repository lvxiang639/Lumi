import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
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
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.ctrl.text.isNotEmpty;
    widget.ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.ctrl != widget.ctrl) {
      old.ctrl.removeListener(_onTextChanged);
      widget.ctrl.addListener(_onTextChanged);
      _hasText = widget.ctrl.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.ctrl.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness;
    final listening = widget.listening;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        border: Border(top: BorderSide(color: AppColors.border(b))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Voice
        GestureDetector(
          onTap: widget.onVoice,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: listening ? AppColors.danger.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? AppColors.danger : AppColors.accent, size: 22),
          ),
        ),
        const SizedBox(width: 6),
        // Text field
        Expanded(child: Container(
          constraints: const BoxConstraints(minHeight: 44, maxHeight: 100),
          decoration: BoxDecoration(
            color: b == Brightness.light ? Colors.white : AppColors.darkCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border(b)),
          ),
          child: TextField(
            controller: widget.ctrl, autofocus: widget.showField,
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => widget.onSend(),
            style: TextStyle(color: AppColors.text(b), fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.showField ? '输入消息...' : '语音输入',
              hintStyle: TextStyle(color: AppColors.textSecondary(b), fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        )),
        const SizedBox(width: 6),
        // Send / Attach
        GestureDetector(
          onTap: _hasText ? widget.onSend : widget.onFile,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _hasText ? AppColors.accent : AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(_hasText ? Icons.send_rounded : Icons.add, color: _hasText ? Colors.white : AppColors.accent, size: 20),
          ),
        ),
      ]),
    );
  }
}
