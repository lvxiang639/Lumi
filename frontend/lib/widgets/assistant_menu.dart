import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AssistantMenu extends StatelessWidget {
  final String? conversationId;
  final VoidCallback onEmailSummary;
  final VoidCallback onNotes;
  final VoidCallback onExtractSummary;
  final VoidCallback? onExport;
  final VoidCallback? onShare;
  final VoidCallback? onDiary;

  const AssistantMenu({
    super.key,
    this.conversationId,
    required this.onEmailSummary,
    required this.onNotes,
    required this.onExtractSummary,
    this.onExport,
    this.onShare,
    this.onDiary,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(brightness),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('助手',
                  style: TextStyle(
                      color: AppColors.text(brightness),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            Divider(
                height: 1, color: AppColors.border(brightness)),
            _menuItem(
              icon: Icons.email_outlined,
              title: '总结发送邮件',
              subtitle: '将当前对话总结发送到邮箱',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.pop(context);
                onEmailSummary();
              },
              brightness: brightness,
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
              brightness: brightness,
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
              brightness: brightness,
            ),
            if (onDiary != null)
              _menuItem(
                icon: Icons.book_outlined,
                title: '生成日记',
                subtitle: '把对话写成一篇温暖的日记',
                color: const Color(0xFF8B5CF6),
                onTap: () { Navigator.pop(context); onDiary!(); },
                brightness: brightness,
              ),
            if (onShare != null)
              _menuItem(
                icon: Icons.share_outlined,
                title: '分享对话',
                subtitle: '生成精美卡片分享给朋友',
                color: const Color(0xFFF97316),
                onTap: () {
                  Navigator.pop(context);
                  onShare!();
                },
                brightness: brightness,
              ),
            if (onExport != null)
              _menuItem(
                icon: Icons.picture_as_pdf_outlined,
                title: '导出文档',
                subtitle: '将对话导出为 PDF 或 Word',
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(context);
                  onExport!();
                },
                brightness: brightness,
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
    required Brightness brightness,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.text(brightness),
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                              AppColors.textSecondary(brightness),
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
