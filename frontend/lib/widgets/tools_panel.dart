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
  const ToolsPanel({super.key});

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
      context.read<ExpenseProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('助手工具',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabs: const [
                Tab(text: '📅 日历'),
                Tab(text: '💰 记账'),
                Tab(text: '📄 文件处理'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CalendarTab(),
                  _ExpenseTab(),
                  _FileProcessingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calendar ──────────────────────────────────────────────────────

class _CalendarTab extends StatelessWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.events.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              Center(
                  child: Text('暂无提醒事件',
                      style: TextStyle(color: Colors.grey))),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.events.length,
          itemBuilder: (context, i) {
            final event = provider.events[i];
            final dt = event.time;
            return ListTile(
              leading: const Icon(Icons.event, color: Colors.indigo),
              title: Text(event.title),
              subtitle: Text(
                  '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => provider.deleteEvent(event.id),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Expense ────────────────────────────────────────────────────────

class _ExpenseTab extends StatelessWidget {
  const _ExpenseTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final totalExpense =
            (provider.stats?['total_expense'] as num?)?.toDouble() ?? 0.0;
        if (provider.records.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              const Center(
                  child: Text('暂无记账记录',
                      style: TextStyle(color: Colors.grey))),
              if (totalExpense > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                        '本月支出: ¥${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.indigo)),
                  ),
                ),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.records.length,
          itemBuilder: (context, i) {
            final record = provider.records[i];
            final isExpense = record.amount > 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isExpense
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Text(record.category,
                    style: const TextStyle(fontSize: 12)),
              ),
              title: Text(
                  record.remark.isEmpty ? record.category : record.remark),
              subtitle: Text(_fmtDt(record.recordedAt)),
              trailing: Text(
                '${isExpense ? "-" : "+"}¥${record.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  color: isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onLongPress: () => provider.delete(record.id),
            );
          },
        );
      },
    );
  }

  static String _fmtDt(DateTime dt) {
    final s = dt.toString();
    return s.length >= 16 ? s.substring(0, 16) : s;
  }
}

// ── File Processing (Conversion + File List) ─────────────────────────

class _FileProcessingTab extends StatefulWidget {
  const _FileProcessingTab();

  @override
  State<_FileProcessingTab> createState() => _FileProcessingTabState();
}

class _FileProcessingTabState extends State<_FileProcessingTab> {
  String? _selectedFile;
  String? _outputFormat;
  bool _converting = false;
  String _status = '';

  // file list state
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
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/tools/files');
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _files = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (_) {}
    setState(() => _loadingFiles = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );
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
    setState(() { _converting = true; _status = '转换中...'; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/convert?target=$_outputFormat');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', _selectedFile!));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final outName = data['target_name'] as String? ?? 'output';
        setState(() {
          _converting = false;
          _status = '✅ 转换完成: $outName';
          _selectedFile = null;
        });
        _loadFiles(); // refresh file list
      } else {
        setState(() { _converting = false; _status = '转换失败'; });
      }
    } catch (e) {
      setState(() { _converting = false; _status = '转换出错: $e'; });
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final sourceExt = _selectedFile != null ? _selectedFile!.split('.').last : '';
    final targetLabel = _outputFormat == 'pdf' ? '📄 PDF' : '📝 Word';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Conversion section ──
          const Icon(Icons.swap_horiz, size: 40, color: Colors.indigo),
          const SizedBox(height: 8),
          const Text('Word ↔ PDF 转换',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('支持 .docx 和 .pdf 互相转换',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('选择文件 (.docx / .pdf)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedFile != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sourceExt.toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: Colors.indigo),
                ),
                Text(targetLabel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _converting ? null : _convert,
              icon: _converting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
              child: Text(_status, textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _status.startsWith('✅') ? Colors.green.shade700 : Colors.grey.shade700,
                  )),
            ),

          // ── File list section ──
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('转换历史',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadFiles,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_loadingFiles)
            const Center(child: CircularProgressIndicator())
          else if (_files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('暂无转换文件',
                      style: TextStyle(color: Colors.grey, fontSize: 13))),
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
                  name.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                  color: name.endsWith('.pdf') ? Colors.red : Colors.blue,
                ),
                title: Text(name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    '${_fmtSize(size)} · ${dt.length >= 16 ? dt.substring(0, 16) : dt}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  onPressed: url.isNotEmpty ? () => _download(url, name) : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
