import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../services/file_service.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

class FilePage extends StatefulWidget {
  const FilePage({super.key});
  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  final FileService _service = FileService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _files = await _service.listFiles();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    final path = file.path!;
    final name = file.name;
    final ext = name.split('.').last.toLowerCase();
    final target = ext == 'pdf' ? 'docx' : 'pdf';

    setState(() => _uploading = true);

    try {
      final token = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/tools/convert?target=$target');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', path));
      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $name → ${ext == 'pdf' ? 'docx' : 'pdf'} 转换完成'),
              duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
        }
        _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ 转换失败'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 出错: $e'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
      }
    }

    setState(() => _uploading = false);
  }

  String _formatSize(dynamic size) {
    if (size == null) return '';
    final s = (size as num).toDouble();
    if (s < 1024) return '${s.toStringAsFixed(0)}B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)}KB';
    return '${(s / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('文件转换', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: Column(
        children: [
          // File list / empty state
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : _files.isEmpty && !_uploading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_outlined, size: 48,
                              color: _textDim.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('还没有转换过文件', style: TextStyle(color: _textDim)),
                            const SizedBox(height: 4),
                            Text('支持 PDF ↔ DOCX', style: TextStyle(color: _textDim.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: _accent, backgroundColor: _surface,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _files.length,
                          itemBuilder: (ctx, i) {
                            final f = _files[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                              child: Row(children: [
                                Container(width: 36, height: 36,
                                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.insert_drive_file, color: _accent, size: 18)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(f['original_name'] as String? ?? '', style: const TextStyle(color: _textMain, fontSize: 13)),
                                    Text('${f['target_name'] as String? ?? ''}  ·  ${_formatSize(f['file_size'])}',
                                      style: TextStyle(color: _textDim.withValues(alpha: 0.6), fontSize: 10)),
                                  ]),
                                ),
                                Text('→', style: TextStyle(color: _textDim, fontSize: 13)),
                              ]),
                            );
                          },
                        ),
                      ),
          ),
          // Bottom upload button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadFile,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_uploading ? '转换中...' : '选择文件转换 (PDF ↔ Word)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}