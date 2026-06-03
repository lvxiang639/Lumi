import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../providers/calendar_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_client.dart';

// ── Shared dark theme constants ──
const _bg = Color(0xFF0B0E1E);
const _surface = Color(0xFF141832);
const _accent = Color(0xFF7C8FFF);
const _textPrimary = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF94A3B8);
const _border = Color(0xFF2A2F5A);
const _cardBg = Color(0xFF141832);

class ToolsPanel extends StatefulWidget {
  final VoidCallback? onClose;
  const ToolsPanel({super.key, this.onClose});
  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel> {
  int _selectedIndex = 0;

  static const _menuItems = [
    _MenuItem(Icons.calendar_month_rounded, '日历', Color(0xFFF59E0B)),
    _MenuItem(Icons.account_balance_wallet_rounded, '记账', Color(0xFF10B981)),
    _MenuItem(Icons.edit_note_rounded, '笔记', Color(0xFF06B6D4)),
    _MenuItem(Icons.document_scanner_rounded, 'OCR', Color(0xFF8B5CF6)),
    _MenuItem(Icons.mood_rounded, '心情', Color(0xFFEC4899)),
    _MenuItem(Icons.swap_horiz_rounded, '文件', Color(0xFF6366F1)),
    _MenuItem(Icons.mail_outline_rounded, '邮件', Color(0xFFEC4899)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
      context.read<ExpenseProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textSecondary),
          onPressed: widget.onClose ?? () => Navigator.pop(context),
        ),
        title: const Text('助手工具',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 68,
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(right: BorderSide(color: _border, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                ...List.generate(_menuItems.length, (i) {
                  final active = i == _selectedIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? _menuItems[i].color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(_menuItems[i].icon,
                              size: 22,
                              color: active ? _menuItems[i].color : _textSecondary),
                          const SizedBox(height: 3),
                          Text(_menuItems[i].label,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: active ? _menuItems[i].color : _textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // ── Content ──
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _CalendarContent(),
                _ExpenseContent(),
                _NotesContent(),
                _OcrContent(),
                _MoodContent(),
                _ConversionContent(),
                _EmailContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem { final IconData icon; final String label; final Color color; const _MenuItem(this.icon, this.label, this.color); }

// ── Calendar ─────────────────────────────────────────────────

class _CalendarContent extends StatelessWidget {
  const _CalendarContent();
  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, p, _) {
        if (p.loading) return const Center(child: CircularProgressIndicator(color: _accent));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('日历提醒', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
              ]),
            ),
            if (p.events.isEmpty)
              const Expanded(child: Center(child: Text('暂无提醒', style: TextStyle(color: _textSecondary))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: p.events.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (_, i) {
                    final e = p.events[i]; final dt = e.time;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _cardBg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const Icon(Icons.event, color: Color(0xFFF59E0B), size: 22),
                        title: Text(e.title, style: const TextStyle(color: _textPrimary, fontSize: 14)),
                        subtitle: Text('${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => p.deleteEvent(e.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Expense ───────────────────────────────────────────────────

class _ExpenseContent extends StatefulWidget {
  const _ExpenseContent();
  @override
  State<_ExpenseContent> createState() => _ExpenseContentState();
}

class _ExpenseContentState extends State<_ExpenseContent> {
  String _period = 'month';

  void _showEditDialog(BuildContext context, ExpenseProvider p, String id, double amount, String category, String remark) {
    final amtCtrl = TextEditingController(text: amount.abs().toStringAsFixed(2));
    final catCtrl = TextEditingController(text: category);
    final remCtrl = TextEditingController(text: remark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('编辑记录', style: TextStyle(color: _textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: _textPrimary),
              decoration: const InputDecoration(labelText: '金额', labelStyle: TextStyle(color: _textSecondary))),
          TextField(controller: catCtrl,
              style: const TextStyle(color: _textPrimary),
              decoration: const InputDecoration(labelText: '分类', labelStyle: TextStyle(color: _textSecondary))),
          TextField(controller: remCtrl,
              style: const TextStyle(color: _textPrimary),
              decoration: const InputDecoration(labelText: '备注', labelStyle: TextStyle(color: _textSecondary))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textSecondary))),
          TextButton(onPressed: () {
            final newAmt = double.tryParse(amtCtrl.text) ?? amount;
            p.update(id, {'amount': amount < 0 ? -newAmt : newAmt, 'category': catCtrl.text, 'remark': remCtrl.text});
            Navigator.pop(ctx);
          }, child: const Text('保存', style: TextStyle(color: _accent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, p, _) {
        if (p.loading) return const Center(child: CircularProgressIndicator(color: _accent));
        final stats = _period == 'week' ? p.weeklyStats : p.stats;
        final totalExpense = (stats?['total_expense'] as num?)?.toDouble() ?? 0.0;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(children: [
              Icon(Icons.account_balance_wallet_rounded, size: 20, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('记账', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _chip('周', 'week'), const SizedBox(width: 8), _chip('月', 'month'), const Spacer(),
              Text('${_period == "week" ? "本周" : "本月"}: ¥${totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
            ]),
          ),
          if (stats != null && stats['by_category'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(spacing: 6, runSpacing: 4,
                children: (stats['by_category'] as Map<String, dynamic>).entries.map((e) => Chip(
                  label: Text('${e.key} ¥${(e.value as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: _textSecondary)),
                  backgroundColor: _cardBg, side: const BorderSide(color: _border),
                )).toList()),
              ),
          const Divider(color: _border, height: 1),
          if (p.records.isEmpty)
            const Expanded(child: Center(child: Text('暂无记录', style: TextStyle(color: _textSecondary))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: p.records.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (_, i) {
                  final r = p.records[i]; final isExpense = r.amount > 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _cardBg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isExpense ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                        radius: 16,
                        child: Text(r.category, style: TextStyle(fontSize: 10, color: isExpense ? Colors.redAccent : Colors.greenAccent)),
                      ),
                      title: Text('${isExpense ? "-" : "+"}¥${r.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: isExpense ? Colors.redAccent : Colors.greenAccent, fontSize: 14)),
                      subtitle: r.remark.isNotEmpty ? Text(r.remark, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _textSecondary)) : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: _textSecondary),
                            onPressed: () => _showEditDialog(context, p, r.id, r.amount, r.category, r.remark)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            onPressed: () => p.delete(r.id)),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]);
      },
    );
  }

  Widget _chip(String label, String period) {
    final active = _period == period;
    return GestureDetector(
      onTap: () => setState(() => _period = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF10B981).withValues(alpha: 0.2) : _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFF10B981).withValues(alpha: 0.4) : _border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? const Color(0xFF10B981) : _textSecondary)),
      ),
    );
  }
}

// ── Conversion ────────────────────────────────────────────────

class _ConversionContent extends StatefulWidget {
  const _ConversionContent();
  @override
  State<_ConversionContent> createState() => _ConversionContentState();
}

class _ConversionContentState extends State<_ConversionContent> {
  String? _selectedFile, _outputFormat;
  bool _converting = false;
  String _status = '';
  List<Map<String, dynamic>> _files = [];
  bool _loadingFiles = false;

  @override
  void initState() { super.initState(); _loadFiles(); }

  Future<void> _loadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/tools/files'),
          headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() { _files = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? []; });
      }
    } catch (_) {}
    setState(() => _loadingFiles = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'pdf']);
    if (result != null && result.files.single.path != null) {
      final name = result.files.single.name; final ext = name.split('.').last.toLowerCase();
      setState(() { _selectedFile = result.files.single.path; _outputFormat = ext == 'pdf' ? 'docx' : 'pdf'; _status = '已选择: $name'; });
    }
  }

  Future<void> _convert() async {
    if (_selectedFile == null || _outputFormat == null) return;
    setState(() { _converting = true; _status = '转换中...'; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/tools/convert?target=$_outputFormat'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', _selectedFile!));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() { _converting = false; _status = '✅ ${data['target_name']}'; _selectedFile = null; });
        _loadFiles();
      } else { setState(() { _converting = false; _status = '转换失败'; }); }
    } catch (e) { setState(() { _converting = false; _status = '出错: $e'; }); }
  }

  Future<void> _download(String url, String name) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final f = File('${(await getTemporaryDirectory()).path}/$name');
        await f.writeAsBytes(resp.bodyBytes);
        if (Platform.isMacOS || Platform.isIOS) await Process.run('open', [f.path]);
      }
    } catch (_) {}
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF6366F1)), SizedBox(width: 8),
          Text('文件处理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
        ]),
        const SizedBox(height: 4),
        const Text('Word ↔ PDF 互相转换', style: TextStyle(fontSize: 13, color: _textSecondary)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file, color: _accent),
          label: const Text('选择文件 (.docx / .pdf)', style: TextStyle(color: _accent)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_selectedFile!.split('.').last.toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: _accent)),
            Text(_outputFormat == 'pdf' ? '📄 PDF' : '📝 Word',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _converting ? null : _convert,
            icon: _converting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
            label: Text(_converting ? '转换中...' : '开始转换'),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
        if (_status.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _status.startsWith('✅') ? const Color(0xFF10B981).withValues(alpha: 0.1) : _cardBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text(_status, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _status.startsWith('✅') ? const Color(0xFF10B981) : _textSecondary)),
          ),
        const SizedBox(height: 20), const Divider(color: _border), const SizedBox(height: 8),
        Row(children: [
          const Text('转换历史', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh, size: 18, color: _textSecondary), onPressed: _loadFiles),
        ]),
        if (_loadingFiles)
          const Center(child: CircularProgressIndicator(color: _accent))
        else if (_files.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('暂无文件', style: TextStyle(color: _textSecondary, fontSize: 13))))
        else
          ...List.generate(_files.length, (i) {
            final f = _files[i]; final name = f['target_name'] as String? ?? '';
            final size = f['file_size'] as int? ?? 0; final url = f['download_url'] as String? ?? '';
            final dt = f['created_at'] as String? ?? '';
            return ListTile(
              leading: Icon(name.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                  color: name.endsWith('.pdf') ? Colors.redAccent : Colors.blueAccent, size: 22),
              title: Text(name, style: const TextStyle(color: _textPrimary, fontSize: 13)),
              subtitle: Text('${_fmtSize(size)} · ${dt.length >= 16 ? dt.substring(0, 16) : dt}',
                  style: const TextStyle(fontSize: 11, color: _textSecondary)),
              trailing: IconButton(icon: const Icon(Icons.download, size: 18, color: _accent),
                  onPressed: url.isNotEmpty ? () => _download(url, name) : null),
            );
          }),
      ]),
    );
  }
}

// ── Email ─────────────────────────────────────────────────────

class _EmailContent extends StatefulWidget {
  const _EmailContent();
  @override
  State<_EmailContent> createState() => _EmailContentState();
}

class _EmailContentState extends State<_EmailContent> {
  bool _sending = false;
  String _status = '';
  List<Map<String, dynamic>> _sentEmails = [];
  bool _loadingList = false;

  @override
  void initState() { super.initState(); _loadSent(); }

  Future<void> _loadSent() async {
    setState(() => _loadingList = true);
    try {
      final data = await ApiClient().get('/api/conversations/sent-emails');
      setState(() { _sentEmails = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? []; });
    } catch (_) {}
    setState(() => _loadingList = false);
  }

  Future<void> _sendSummary() async {
    final convId = context.read<ChatProvider>().conversationId;
    if (convId == null) { setState(() => _status = '请先开始对话'); return; }
    setState(() { _sending = true; _status = '发送中...'; });
    try {
      await ApiClient().post('/api/conversations/$convId/email-summary');
      setState(() { _sending = false; _status = '✅ 已发送'; });
      _loadSent();
    } on ApiException catch (e) {
      setState(() => _sending = false);
      if (e.statusCode == 400 && e.body.contains('邮箱')) { _showEmailSetup(); } else { _status = '发送失败'; }
    } catch (_) { setState(() { _sending = false; _status = '发送失败'; }); }
  }

  void _showEmailSetup() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('设置邮箱', style: TextStyle(color: _textPrimary)),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(hintText: '输入邮箱地址', hintStyle: TextStyle(color: _textSecondary))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textSecondary))),
          TextButton(onPressed: () async {
            final email = ctrl.text.trim(); if (email.isEmpty) return;
            try { await ApiClient().put('/api/auth/profile', body: {'email': email}); if (ctx.mounted) Navigator.pop(ctx); _sendSummary(); } catch (_) {}
          }, child: const Text('保存并发送', style: TextStyle(color: _accent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.mail_outline_rounded, size: 40, color: Color(0xFFEC4899)),
        const SizedBox(height: 12),
        const Text('📧 对话邮件摘要', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
        const SizedBox(height: 4),
        const Text('发送最新对话摘要到你的邮箱，并查看历史记录',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _textSecondary)),
        const SizedBox(height: 20),

        // Send button
        ElevatedButton.icon(
          onPressed: _sending ? null : _sendSummary,
          icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, size: 18),
          label: Text(_sending ? '发送中...' : '发送最新的对话摘要'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_status, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _status.startsWith('✅') ? const Color(0xFF10B981) : _textSecondary)),
          ),

        const SizedBox(height: 24),
        const Divider(color: _border),
        const SizedBox(height: 8),
        Row(children: [
          const Text('发送记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh, size: 18, color: _textSecondary), onPressed: _loadSent),
        ]),

        if (_loadingList)
          const Center(child: CircularProgressIndicator(color: _accent))
        else if (_sentEmails.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无发送记录', style: TextStyle(color: _textSecondary, fontSize: 13))))
        else
          ...List.generate(_sentEmails.length, (i) {
            final e = _sentEmails[i];
            final title = e['conv_title'] as String? ?? '';
            final recipient = e['recipient'] as String? ?? '';
            final preview = e['summary_preview'] as String? ?? '';
            final sentAt = e['sent_at'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _cardBg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(title, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text(preview, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(recipient, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                  const Spacer(),
                  Text(sentAt.length >= 16 ? sentAt.substring(0, 16) : sentAt, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                ]),
              ]),
            );
          }),
      ]),
    );
  }

// ── Notes ──────────────────────────────────────────────────────────

class _NotesContent extends StatefulWidget {
  const _NotesContent();
  @override
  State<_NotesContent> createState() => _NotesContentState();
}

class _NotesContentState extends State<_NotesContent> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient().get('/api/notes?note_type=note');
      setState(() => _notes = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final t = TextEditingController(), c = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _surface,
      title: const Text('新建笔记', style: TextStyle(color: _textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: t, style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(hintText: '标题', hintStyle: TextStyle(color: _textSecondary))),
        TextField(controller: c, maxLines: 4, style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(hintText: '内容', hintStyle: TextStyle(color: _textSecondary))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textSecondary))),
        TextButton(onPressed: () async {
          if (c.text.trim().isEmpty) return;
          await ApiClient().post('/api/notes', body: {'title': t.text, 'content': c.text, 'note_type': 'note'});
          Navigator.pop(ctx); _load();
        }, child: const Text('保存', style: TextStyle(color: _accent))),
      ],
    ));
  }

  Future<void> _delete(String id) async {
    await ApiClient().delete('/api/notes/$id'); _load();
  }

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,20,16,8), child: Row(children: [
      const Icon(Icons.edit_note_rounded, size:20, color:Color(0xFF06B6D4)), const SizedBox(width:8),
      const Text('笔记', style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:_textPrimary)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.add, color: _accent), onPressed: _add),
    ])),
    if (_loading) const Center(child: CircularProgressIndicator(color: _accent))
    else if (_notes.isEmpty) const Expanded(child: Center(child: Text('暂无笔记', style: TextStyle(color: _textSecondary))))
    else Expanded(child: ListView.builder(
      itemCount: _notes.length, padding: const EdgeInsets.symmetric(horizontal:8),
      itemBuilder: (_,i){ final n=_notes[i];
        return Container(margin: const EdgeInsets.symmetric(horizontal:8, vertical:3),
          decoration: BoxDecoration(color: _cardBg.withValues(alpha:0.6), borderRadius: BorderRadius.circular(10)),
          child: ListTile(title: Text(n['title'] as String? ?? '', style: const TextStyle(color: _textPrimary, fontSize:14)),
            subtitle: Text((n['content'] as String? ?? ''), maxLines:2, overflow:TextOverflow.ellipsis,
                style: const TextStyle(color: _textSecondary, fontSize:12)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, size:18, color:Colors.redAccent), onPressed: ()=>_delete(n['id'] as String)),
          ),
        );
      },
    )),
  ]);
}

// ── OCR ────────────────────────────────────────────────────────────

class _OcrContent extends StatefulWidget {
  const _OcrContent();
  @override
  State<_OcrContent> createState() => _OcrContentState();
}

class _OcrContentState extends State<_OcrContent> {
  String _result = '';
  bool _loading = false;

  Future<void> _scan() async {
    final r = await FilePicker.pickFiles(type: FileType.image);
    if (r == null || r.files.single.path == null) return;
    setState(() { _loading = true; _result = '识别中...'; });
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/tools/ocr'))
        ..headers['Authorization'] = 'Bearer $tok'
        ..files.add(await http.MultipartFile.fromPath('file', r.files.single.path!));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        final type = d['type'] as String? ?? 'text';
        final typeLabel = {'receipt':'🧾 发票','card':'👤 名片','text':'📄 文字'}[type]??'📄';
        setState(() { _loading = false; _result = '$typeLabel\n${d['text']}'; });
      } else { setState(() { _loading = false; _result = '识别失败'; }); }
    } catch (e) { setState(() { _loading = false; _result = '出错: $e'; }); }
  }

  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Row(children: [Icon(Icons.document_scanner_rounded, size:20, color:Color(0xFF8B5CF6)), SizedBox(width:8),
      Text('图片 OCR', style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:_textPrimary))]),
    const SizedBox(height:4),
    const Text('拍照识别文字，支持发票、名片、普通文字', style: TextStyle(fontSize:12, color:_textSecondary)),
    const SizedBox(height:16),
    ElevatedButton.icon(onPressed: _loading?null:_scan,
      icon: _loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.camera_alt),
      label: Text(_loading?'识别中...':'拍照 / 选择图片'),
      style: ElevatedButton.styleFrom(backgroundColor:const Color(0xFF8B5CF6),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))),
    if (_result.isNotEmpty) Container(margin:const EdgeInsets.only(top:16),padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:_cardBg,borderRadius:BorderRadius.circular(10)),
      child: SelectableText(_result, style: const TextStyle(color:_textPrimary, fontSize:14, height:1.6))),
  ]));
}

// ── Mood ───────────────────────────────────────────────────────────

class _MoodContent extends StatefulWidget {
  const _MoodContent();
  @override
  State<_MoodContent> createState() => _MoodContentState();
}

class _MoodContentState extends State<_MoodContent> {
  List<Map<String, dynamic>> _moods = [];
  Map<String, int> _stats = {};
  bool _loading = false;

  static const _emotions = [
    ('😊', 'joy'), ('😢', 'sad'), ('😠', 'angry'),
    ('😌', 'calm'), ('😲', 'surprised'), ('😟', 'worried'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient();
      final moodsData = await api.get('/api/notes/moods');
      _moods = (moodsData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final statsData = await api.get('/api/notes/moods/stats?period=week');
      _stats = (statsData['by_emotion'] as Map?)?.map((k,v)=>(k as String, v as int)) ?? {};
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _log(String emotion) async {
    await ApiClient().post('/api/notes/moods', body: {'emotion': emotion, 'intensity': 1.0});
    _load();
  }

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.fromLTRB(16,20,16,8), child: Row(children: [
      Icon(Icons.mood_rounded, size:20, color:Color(0xFFEC4899)), SizedBox(width:8),
      Text('心情日记', style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:_textPrimary))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Wrap(spacing:8,
      children: _emotions.map((e) => GestureDetector(onTap:()=>_log(e.$2), child: Chip(
        avatar: Text(e.$1, style: const TextStyle(fontSize:18)),
        label: Text(e.$2, style: const TextStyle(fontSize:11, color:_textSecondary)),
        backgroundColor: _cardBg, side: const BorderSide(color:_border),
      ))).toList())),
    if (_stats.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing:8, runSpacing:4,
      children: _stats.entries.where((e)=>e.value>0).map((e)=>Chip(
        label: Text('${_emotions.firstWhere((x)=>x.$2==e.key).$1} ×${e.value}', style: const TextStyle(fontSize:12, color:_textSecondary)),
        backgroundColor: _cardBg,
      )).toList()))),
    const Divider(color: _border),
    if (_loading) const Center(child: CircularProgressIndicator(color: _accent))
    else if (_moods.isEmpty) const Expanded(child: Center(child: Text('暂无记录', style: TextStyle(color: _textSecondary))))
    else Expanded(child: ListView.builder(itemCount: _moods.length, padding: const EdgeInsets.symmetric(horizontal:8),
      itemBuilder:(_,i){ final m=_moods[i]; final emo=_emotions.firstWhere((e)=>e.$2==(m['emotion']??''), orElse:()=>('❓',''));
        return ListTile(leading: Text(emo.$1, style: const TextStyle(fontSize:22)),
          title: Text(m['emotion'] as String? ?? '', style: const TextStyle(color: _textPrimary, fontSize:14)),
          subtitle: Text((m['created_at'] as String? ?? '').length>=16?(m['created_at'] as String).substring(0,16):'',
              style: const TextStyle(fontSize:11, color:_textSecondary)));
      })),
  ]);
}
