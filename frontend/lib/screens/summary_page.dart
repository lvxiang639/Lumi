import 'package:flutter/material.dart';
import '../services/conversation_service.dart';
import '../theme/app_colors.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final ConversationService _service = ConversationService();
  List<Map<String, dynamic>> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _summaries = await _service.listSummaries();
    } catch (_) {}
    setState(() => _loading = false);
  }

  String _formatTime(dynamic dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt as String);
      return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showDetail(Map<String, dynamic> s, Brightness b) {
    final title = s['conv_title'] as String? ?? '';
    final summary = s['summary_text'] as String? ?? '';
    final time = _formatTime(s['updated_at']);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, maxChildSize: 0.8, minChildSize: 0.3, expand: false,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
              Expanded(child: Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600))),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary(b))),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(time, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12))),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: SelectableText(summary.isNotEmpty ? summary : '暂无摘要内容', style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.7)))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.textSecondary(brightness)),
            onPressed: () => Navigator.pop(context)),
        title: Text('提炼摘要',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _summaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.article_outlined, size: 32, color: AppColors.accent.withValues(alpha: 0.5))),
                      const SizedBox(height: 16),
                      Text('还没有摘要记录',
                          style: TextStyle(
                              color: AppColors.text(brightness), fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('在对话中使用"提炼摘要"功能即可生成',
                          style: TextStyle(
                              color: AppColors.textSecondary(brightness),
                              fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card(brightness),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _summaries.length,
                    itemBuilder: (ctx, i) {
                      final s = _summaries[i];
                      return GestureDetector(
                        onTap: () => _showDetail(s, brightness),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card(brightness),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                        child: Text('📋',
                                            style: TextStyle(
                                                fontSize: 14))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        s['conv_title'] as String? ?? '',
                                        style: TextStyle(
                                            color: AppColors.text(
                                                brightness),
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ),
                                  Text(_formatTime(s['updated_at']),
                                      style: TextStyle(
                                          color: AppColors.textSecondary(
                                                  brightness)
                                              .withValues(alpha: 0.4),
                                          fontSize: 10)),
                                ]),
                                const SizedBox(height: 8),
                                Text(s['summary_text'] as String? ?? '',
                                    style: TextStyle(
                                        color: AppColors.textSecondary(
                                            brightness),
                                        fontSize: 12,
                                        height: 1.5)),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
