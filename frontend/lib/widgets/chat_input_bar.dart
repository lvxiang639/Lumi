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

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _hasText = widget.ctrl.text.isNotEmpty;
    widget.ctrl.addListener(_onTextChanged);
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200),
    );
    if (_hasText) _pulseCtrl.forward();
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
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.ctrl.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _pulseCtrl.forward();
      } else {
        _pulseCtrl.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness;
    final listening = widget.listening;

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        border: Border(top: BorderSide(color: AppColors.border(b).withValues(alpha: 0.3))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Voice button
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: listening
                ? AppColors.danger.withValues(alpha: 0.12)
                : AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(listening ? Icons.mic : Icons.mic_none,
                color: listening ? AppColors.danger : AppColors.accent, size: 20),
            onPressed: widget.onVoice,
            padding: EdgeInsets.zero,
            splashRadius: 18,
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: b == Brightness.light
                  ? const Color(0xFFF1F3F5)
                  : const Color(0xFF1C212B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.border(b).withValues(alpha: 0.5),
              ),
            ),
            child: TextField(
              controller: widget.ctrl,
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.3),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary(b).withValues(alpha: 0.4),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send / Add button (animated)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _hasText
              ? Container(
                  key: const ValueKey('send'),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    color: Colors.white,
                    onPressed: widget.onSend,
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                  ),
                )
              : Container(
                  key: const ValueKey('add'),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add_rounded, color: AppColors.accent, size: 22),
                    onPressed: widget.onFile,
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                  ),
                ),
        ),
      ]),
    );
  }
}
