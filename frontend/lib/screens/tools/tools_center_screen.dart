import 'package:flutter/material.dart';
import '../calendar_page.dart';
import '../expense_page.dart';
import '../notes_page.dart';
import '../email_page.dart';
import '../file_page.dart';
import '../summary_page.dart';
import '../countdown_page.dart';
import '../knowledge_page.dart';
import '../study_page.dart';
import '../ocr_page.dart';
import '../../services/routes.dart';
import '../../theme/app_colors.dart';

class ToolsCenterScreen extends StatelessWidget {
  const ToolsCenterScreen({super.key});

  static const _tools = <_Tool>[
    _Tool('日历', Icons.calendar_month, Color(0xFFF59E0B)),
    _Tool('记账', Icons.account_balance_wallet, Color(0xFF10B981)),
    _Tool('笔记', Icons.note_alt, Color(0xFF3B82F6)),
    _Tool('邮件', Icons.email, Color(0xFF8B5CF6)),
    _Tool('文档', Icons.description_outlined, Color(0xFF14B8A6)),
    _Tool('摘要', Icons.summarize, Color(0xFFF97316)),
    _Tool('OCR', Icons.document_scanner, Color(0xFF06B6D4)),
    _Tool('倒数日', Icons.date_range, Color(0xFFEF4444)),
    _Tool('辅导', Icons.school, Color(0xFF3B82F6)),
    _Tool('知识库', Icons.library_books, Color(0xFF8B5CF6)),
  ];

  void _navigate(BuildContext ctx, String name) {
    Widget page;
    switch (name) {
      case '日历':
        page = const CalendarPage();
        break;
      case '记账':
        page = const ExpensePage();
        break;
      case '笔记':
        page = const NotesPage();
        break;
      case '邮件':
        page = const EmailPage();
        break;
      case '文档':
        page = const FilePage();
        break;
      case '摘要':
        page = const SummaryPage();
        break;
      case '倒数日':
        page = const CountdownPage();
        break;
      case '辅导': page = const StudyPage(); break;
      case 'OCR': page = const OcrPage(); break;
      case '知识库':
        page = const KnowledgePage();
        break;
      default:
        return;
    }
    Navigator.push(ctx, slideRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(title: const Text('工具中心')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: _tools.length,
          itemBuilder: (ctx, i) => _toolCard(ctx, _tools[i], brightness),
        ),
      ),
    );
  }

  Widget _toolCard(BuildContext ctx, _Tool tool, Brightness b) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: () => _navigate(ctx, tool.name),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(b),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              tool.name,
              style: TextStyle(
                color: AppColors.text(b),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      ),
    ); // Material + InkWell
  }
}

class _Tool {
  final String name;
  final IconData icon;
  final Color color;
  const _Tool(this.name, this.icon, this.color);
}
