import 'package:flutter/material.dart';

// ── Palette ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _border = Color(0x1AFFFFFF);

class AssistantMenu extends StatelessWidget {
  final String? conversationId;
  final VoidCallback onEmailSummary;
  final VoidCallback onNotes;
  final VoidCallback onExtractSummary;

  const AssistantMenu({
    super.key,
    this.conversationId,
    required this.onEmailSummary,
    required this.onNotes,
    required this.onExtractSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: _accent.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('助手', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(color: _border, height: 1),
            _menuItem(
              icon: Icons.email_outlined,
              title: '总结发送邮件',
              subtitle: '将当前对话总结发送到邮箱',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.pop(context);
                onEmailSummary();
              },
            ),
            _menuItem(
              icon: Icons.note_alt_outlined,
              title: '记笔记',
              subtitle: '将对话内容保存为笔记',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                onNotes();
              },
            ),
            _menuItem(
              icon: Icons.summarize_outlined,
              title: '提炼摘要',
              subtitle: '快速提取对话核心要点',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(context);
                onExtractSummary();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _textDim, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}