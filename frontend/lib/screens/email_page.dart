import 'package:flutter/material.dart';
import '../services/email_service.dart';
import '../theme/app_colors.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({super.key});
  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final EmailService _service = EmailService();
  List<Map<String, dynamic>> _emails = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _emails = await _service.listSentEmails();
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
        title: Text('邮件记录',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _emails.isEmpty
              ? Center(
                  child: Text('还没有发送过邮件',
                      style: TextStyle(
                          color: AppColors.textSecondary(brightness))))
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card(brightness),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _emails.length,
                    itemBuilder: (ctx, i) {
                      final e = _emails[i];
                      return Container(
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
                                const Icon(Icons.email_outlined,
                                    color: AppColors.accent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(e['conv_title'] as String? ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: AppColors.text(brightness),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 8),
                                Text(_formatTime(e['sent_at']),
                                    style: TextStyle(
                                        color: AppColors.textSecondary(
                                                brightness)
                                            .withValues(alpha: 0.5),
                                        fontSize: 10)),
                              ]),
                              const SizedBox(height: 4),
                              Text(e['recipient'] as String? ?? '',
                                  style: TextStyle(
                                      color: AppColors.textSecondary(
                                          brightness),
                                      fontSize: 11)),
                              if ((e['summary_preview'] as String? ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(e['summary_preview'] as String,
                                    style: TextStyle(
                                        color: AppColors.textSecondary(
                                                brightness)
                                            .withValues(alpha: 0.6),
                                        fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ]),
                      );
                    },
                  ),
                ),
    );
  }
}
