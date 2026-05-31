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
                Tab(text: '🔄 转换'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CalendarTab(),
                  _ExpenseTab(),
                  _ConversionTab(),
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

// ── Conversion ─────────────────────────────────────────────────────

class _ConversionTab extends StatefulWidget {
  const _ConversionTab();

  @override
  State<_ConversionTab> createState() => _ConversionTabState();
}

class _ConversionTabState extends State<_ConversionTab> {
  String? _selectedFile;
  String? _outputFormat;
  bool _converting = false;
  String _status = '';

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
        ..files.add(await http.MultipartFile.fromPath('file', _selectedFile!));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final outName = _selectedFile!
            .split('/')
            .last
            .replaceAll(RegExp(r'\.\w+$'), '.$_outputFormat');
        final outFile = File('${dir.path}/$outName');
        await outFile.writeAsBytes(resp.bodyBytes);

        setState(() {
          _converting = false;
          _status = '✅ 转换完成: $outName (已保存到临时目录)';
        });

        // Open with system default app
        if (Platform.isMacOS || Platform.isIOS) {
          await Process.run('open', [outFile.path]);
        }
      } else {
        final body = resp.body;
        setState(() {
          _converting = false;
          _status = '转换失败: $body';
        });
      }
    } catch (e) {
      setState(() {
        _converting = false;
        _status = '转换出错: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceExt =
        _selectedFile != null ? _selectedFile!.split('.').last : '';
    final targetLabel =
        _outputFormat == 'pdf' ? '📄 PDF' : '📝 Word';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.swap_horiz, size: 48, color: Colors.indigo),
          const SizedBox(height: 12),
          const Text('Word ↔ PDF 转换',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('支持 .docx 和 .pdf 互相转换',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),

          // Step 1: pick file
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('选择文件 (.docx / .pdf)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Source → target
          if (_selectedFile != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sourceExt.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.arrow_forward, color: Colors.indigo),
                ),
                Text(targetLabel,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Convert button
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

          const SizedBox(height: 16),

          // Status
          if (_status.isNotEmpty)
            Container(
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
                        : Colors.grey.shade700,
                  )),
            ),
        ],
      ),
    );
  }
}
