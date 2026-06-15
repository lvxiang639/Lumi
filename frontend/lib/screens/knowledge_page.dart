import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../theme/app_colors.dart';
import '../services/routes.dart';
import 'knowledge_chat_page.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});
  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/knowledge'), headers: {'Authorization': 'Bearer $tok'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _upload() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx', 'txt']);
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;
    setState(() => _uploading = true);
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/knowledge/upload');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $tok'
        ..fields['title'] = file.name
        ..files.add(await http.MultipartFile.fromPath('file', file.path!));
      final resp = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        _load();
        if (mounted) _snack('知识库创建成功');
      } else {
        String errMsg = '上传失败';
        try {
          final body = json.decode(resp.body);
          errMsg = body['detail'] as String? ?? errMsg;
        } catch (_) {}
        if (mounted) _snack(errMsg);
      }
    } catch (e) {
      if (mounted) _snack('上传失败: $e');
    }
    setState(() => _uploading = false);
  }

  Future<void> _delete(String id) async {
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      await http.delete(Uri.parse('${AppConfig.apiBaseUrl}/api/knowledge/$id'), headers: {'Authorization': 'Bearer $tok'});
      _load();
    } catch (_) {}
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary(b)), onPressed: () => Navigator.pop(context)),
        title: Text('知识库', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _items.isEmpty
              ? _emptyState(b)
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final id = item['id'] as String;
                      final title = item['title'] as String? ?? '';
                      return GestureDetector(
                        onTap: () => Navigator.push(context, slideRoute(KnowledgeChatPage(kbId: id, kbTitle: title))),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(width: 42, height: 42,
                            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.library_books, color: Color(0xFF8B5CF6), size: 22)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('${item['chunk_count'] ?? 0} 个文本块', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
                          ])),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _delete(id)),
                        ]),
                      ));
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _upload,
        backgroundColor: AppColors.accent,
        child: _uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.library_books_outlined, size: 32, color: AppColors.accent.withValues(alpha: 0.5))),
      const SizedBox(height: 16),
      Text('创建你的知识库', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('上传 PDF/Word/TXT，AI 基于文档回答', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('上传文档')),
    ]),
  );
}
