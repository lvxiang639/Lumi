import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});
  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  String? _text;
  Uint8List? _imageBytes;
  String? _imageMime;
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() { super.initState(); _loadRecords(); }

  Future<void> _loadRecords() async {
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final resp = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/tools/ocr/records'),
        headers: {'Authorization': 'Bearer $tok'},
      );
      if (resp.statusCode == 200) {
        _records = (json.decode(resp.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _pickAndOcr() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final bytes = File(path).readAsBytesSync();
    setState(() { _loading = true; _text = null; _imageBytes = bytes; });

    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      var req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/tools/ocr'))
        ..headers['Authorization'] = 'Bearer $tok'
        ..files.add(await http.MultipartFile.fromPath('file', path));
      final resp = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _text = data['text'] as String?;
        _loadRecords();
      } else {
        _snack('识别失败');
      }
    } catch (e) {
      _snack('识别失败: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showDetail(Map<String, dynamic> record, Brightness b) async {
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final resp = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/tools/ocr/records/${record['id']}'),
        headers: {'Authorization': 'Bearer $tok'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (mounted) {
          showModalBottomSheet(
            context: context, isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
              builder: (ctx2, sc) => Container(
                decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Column(children: [
                  Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                    const Expanded(child: Text('OCR 结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary(b))),
                  ])),
                  const SizedBox(height: 12),
                  const Divider(),
                  Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Image
                    if ((data['image_base64'] as String?)?.isNotEmpty == true)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(base64Decode((data['image_base64'] as String).split(',').last), fit: BoxFit.contain),
                      ),
                    const SizedBox(height: 16),
                    // Text
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21), borderRadius: BorderRadius.circular(12)),
                      child: SelectableText(data['text'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6)),
                    ),
                  ]))),
                ]),
              ),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary(b)), onPressed: () => Navigator.pop(context)),
        title: Text('OCR 文字识别', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
        : CustomScrollView(slivers: [
        // Result area
        if (_text != null)
          SliverToBoxAdapter(child: Container(
            width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_imageBytes != null)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_imageBytes!, height: 120, fit: BoxFit.contain)),
              const SizedBox(height: 12),
              SelectableText(_text ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6)),
            ]),
          )),
        // History
        if (_records.isEmpty)
          SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.document_scanner, size: 32, color: AppColors.accent.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            Text('还没有识别记录', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('点击下方按钮拍照或选择图片', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
          ])))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) {
              final r = _records[i];
              return GestureDetector(
                onTap: () => _showDetail(r, b),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.document_scanner, size: 18, color: AppColors.accent)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r['text'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text(b), fontSize: 13))),
                    Text(_fmtTime(r['created_at']), style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)),
                  ]),
                ),
              );
            },
            childCount: _records.length,
          )),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _pickAndOcr,
        backgroundColor: AppColors.accent,
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }

  String _fmtTime(dynamic dt) {
    if (dt == null) return '';
    try { final d = DateTime.parse(dt as String); return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return ''; }
  }
}
