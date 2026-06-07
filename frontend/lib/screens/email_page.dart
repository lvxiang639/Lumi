import 'package:flutter/material.dart';
import '../services/email_service.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

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
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('邮件记录', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _emails.isEmpty
              ? Center(child: Text('还没有发送过邮件', style: TextStyle(color: _textDim)))
              : RefreshIndicator(
                  color: _accent, backgroundColor: _surface,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _emails.length,
                    itemBuilder: (ctx, i) {
                      final e = _emails[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.email_outlined, color: _accent, size: 16),
                            const SizedBox(width: 8),
                            Text(e['conv_title'] as String? ?? '', style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text(_formatTime(e['sent_at']), style: TextStyle(color: _textDim.withValues(alpha: 0.5), fontSize: 10)),
                          ]),
                          const SizedBox(height: 4),
                          Text(e['recipient'] as String? ?? '', style: TextStyle(color: _textDim, fontSize: 11)),
                          if ((e['summary_preview'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(e['summary_preview'] as String, style: TextStyle(color: _textDim.withValues(alpha: 0.6), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}