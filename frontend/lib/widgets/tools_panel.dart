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

class ToolsPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const ToolsPanel({super.key, this.onClose});

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel> {
  int _selectedIndex = 0;

  static const _menuItems = [
    _MenuItem(Icons.calendar_month, '日历', Color(0xFFF59E0B)),
    _MenuItem(Icons.account_balance_wallet, '记账', Color(0xFF10B981)),
    _MenuItem(Icons.swap_horiz, '文件处理', Color(0xFF6366F1)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: widget.onClose ?? () => Navigator.pop(context),
        ),
        title: const Text('助手工具',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Row(
          children: [
            // ── Left vertical menu ──
            Container(
              width: 68,
              decoration: const BoxDecoration(
                color: Color(0xFF111530),
                border: Border(
                  right: BorderSide(color: Color(0xFF2A2F5A), width: 1),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Text('助手工具',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white38)),
                  const SizedBox(height: 12),
                  ...List.generate(_menuItems.length, (i) {
                    final active = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF7C8FFF).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(_menuItems[i].icon,
                                size: 22,
                                color: active
                                    ? _menuItems[i].color
                                    : Colors.white38),
                            const SizedBox(height: 4),
                            Text(_menuItems[i].label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: active
                                        ? _menuItems[i].color
                                        : Colors.white38)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                ],
              ),
            ),
            // ── Right content panel ──
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  _CalendarContent(),
                  _ExpenseContent(),
                  _ConversionContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem(this.icon, this.label, this.color);
}

// ── Calendar ──────────────────────────────────────────────────────

class _CalendarContent extends StatelessWidget {
  const _CalendarContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, p, _) {
        if (p.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text('📅 日历提醒',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            if (p.events.isEmpty)
              const Expanded(
                  child:
                      Center(child: Text('暂无提醒', style: TextStyle(color: Colors.grey))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: p.events.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (_, i) {
                    final e = p.events[i];
                    final dt = e.time;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: ListTile(
                        leading:
                            const Icon(Icons.event, color: Colors.indigo),
                        title: Text(e.title),
                        subtitle: Text(
                            '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.redAccent),
                          onPressed: () {
                            p.deleteEvent(e.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已删除')),
                            );
                          },
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

// ── Expense ────────────────────────────────────────────────────────

class _ExpenseContent extends StatefulWidget {
  const _ExpenseContent();

  @override
  State<_ExpenseContent> createState() => _ExpenseContentState();
}

class _ExpenseContentState extends State<_ExpenseContent> {
  String _period = 'month'; // 'week' or 'month'

  void _showEditDialog(BuildContext context, ExpenseProvider p,
      String id, double amount, String category, String remark) {
    final amtCtrl =
        TextEditingController(text: amount.abs().toStringAsFixed(2));
    final catCtrl = TextEditingController(text: category);
    final remCtrl = TextEditingController(text: remark);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '金额'),
            ),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: '分类'),
            ),
            TextField(
              controller: remCtrl,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newAmt = double.tryParse(amtCtrl.text) ?? amount;
              p.update(id, {
                'amount': amount < 0 ? -newAmt : newAmt,
                'category': catCtrl.text,
                'remark': remCtrl.text,
              });
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, p, _) {
        if (p.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = _period == 'week' ? p.weeklyStats : p.stats;
        final totalExpense =
            (stats?['total_expense'] as num?)?.toDouble() ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('💰 记账',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),

            // ── Summary card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _summaryChip('周', 'week'),
                  const SizedBox(width: 8),
                  _summaryChip('月', 'month'),
                  const Spacer(),
                  Text(
                      '${_period == "week" ? "本周" : "本月"}支出: ¥${totalExpense.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Category breakdown ──
            if (stats != null && stats!['by_category'] != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: (stats!['by_category'] as Map<String, dynamic>)
                      .entries
                      .map((e) => Chip(
                            label: Text(
                                '${e.key} ¥${(e.value as num).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey.shade200,
                          ))
                      .toList(),
                ),
              ),

            const Divider(),

            // ── Records list ──
            if (p.records.isEmpty)
              const Expanded(
                  child: Center(
                      child: Text('暂无记录',
                          style: TextStyle(color: Colors.grey))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: p.records.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (_, i) {
                    final r = p.records[i];
                    final isExpense = r.amount > 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isExpense
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          radius: 18,
                          child: Text(r.category,
                              style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text(
                          '${isExpense ? "-" : "+"}¥${r.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        subtitle: r.remark.isNotEmpty
                            ? Text(r.remark,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18),
                              onPressed: () => _showEditDialog(
                                  context,
                                  p,
                                  r.id,
                                  r.amount,
                                  r.category,
                                  r.remark),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.redAccent),
                              onPressed: () => p.delete(r.id),
                            ),
                          ],
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

  Widget _summaryChip(String label, String period) {
    final active = _period == period;
    return GestureDetector(
      onTap: () => setState(() => _period = period),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: active ? Colors.indigo.shade100 : Colors.grey.shade200,
      ),
    );
  }
}

// ── Conversion ─────────────────────────────────────────────────────

class _ConversionContent extends StatefulWidget {
  const _ConversionContent();

  @override
  State<_ConversionContent> createState() => _ConversionContentState();
}

class _ConversionContentState extends State<_ConversionContent> {
  String? _selectedFile;
  String? _outputFormat;
  bool _converting = false;
  String _status = '';
  List<Map<String, dynamic>> _files = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final resp = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/api/tools/files'),
          headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _files = (data['items'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
        });
      }
    } catch (_) {}
    setState(() => _loadingFiles = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx', 'pdf']);
    if (result != null && result.files.single.path != null) {
      final name = result.files.single.name;
      final ext = name.split('.').last.toLowerCase();
      setState(() {
        _selectedFile = result.files.single.path;
        _outputFormat = ext == 'pdf' ? 'docx' : 'pdf';
        _status = '已选择: $name';
      });
    }
  }

  Future<void> _convert() async {
    if (_selectedFile == null || _outputFormat == null) return;
    setState(() {
      _converting = true;
      _status = '转换中...';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/convert?target=$_outputFormat');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _selectedFile!));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final outName = data['target_name'] as String? ?? 'output';
        setState(() {
          _converting = false;
          _status = '✅ $outName';
          _selectedFile = null;
        });
        _loadFiles();
      } else {
        setState(() { _converting = false; _status = '转换失败'; });
      }
    } catch (e) {
      setState(() { _converting = false; _status = '出错: $e'; });
    }
  }

  Future<void> _download(String url, String name) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/$name');
        await f.writeAsBytes(resp.bodyBytes);
        if (Platform.isMacOS || Platform.isIOS) {
          await Process.run('open', [f.path]);
        }
      }
    } catch (_) {}
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final sourceExt =
        _selectedFile != null ? _selectedFile!.split('.').last : '';
    final targetLabel =
        _outputFormat == 'pdf' ? '📄 PDF' : '📝 Word';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('📄 文件处理',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Word ↔ PDF 互相转换',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('选择文件 (.docx / .pdf)'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 12),

          if (_selectedFile != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sourceExt.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.indigo),
                ),
                Text(targetLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _converting ? null : _convert,
              icon: _converting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(_converting ? '转换中...' : '开始转换'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],

          if (_status.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status.startsWith('✅')
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: _status.startsWith('✅')
                          ? Colors.green.shade700
                          : Colors.grey.shade700)),
            ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              const Text('转换历史',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadFiles),
            ],
          ),

          if (_loadingFiles)
            const Center(child: CircularProgressIndicator())
          else if (_files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('暂无文件',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13))),
            )
          else
            ...List.generate(_files.length, (i) {
              final f = _files[i];
              final name = f['target_name'] as String? ?? '';
              final size = f['file_size'] as int? ?? 0;
              final url = f['download_url'] as String? ?? '';
              final dt = f['created_at'] as String? ?? '';
              return ListTile(
                leading: Icon(
                  name.endsWith('.pdf')
                      ? Icons.picture_as_pdf
                      : Icons.description,
                  color: name.endsWith('.pdf')
                      ? Colors.red
                      : Colors.blue,
                ),
                title: Text(name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    '${_fmtSize(size)} · ${dt.length >= 16 ? dt.substring(0, 16) : dt}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                trailing: IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  onPressed:
                      url.isNotEmpty ? () => _download(url, name) : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
