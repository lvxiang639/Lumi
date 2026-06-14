import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../config.dart';
import '../theme/app_colors.dart';
import 'homophone_page.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  int _tab = 0;
  final _qCtrl = TextEditingController();
  String _childName = '';
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _analysis;
  bool _loading = false;
  String _filterSubject = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final h = {'Authorization': 'Bearer $tok'};
    final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/study/records'), headers: h);
    if (r.statusCode == 200) _records = (json.decode(r.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final ar = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/study/analysis'), headers: h);
    if (ar.statusCode == 200) _analysis = json.decode(ar.body);
    setState(() {});
  }

  Future<void> _solve({String? imagePath}) async {
    setState(() => _loading = true);
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      var req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/study/solve'))
        ..headers['Authorization'] = 'Bearer $tok'
        ..fields['question'] = _qCtrl.text
        ..fields['child_name'] = _childName;
      if (imagePath != null) req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      final resp = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        _result = json.decode(resp.body);
        _qCtrl.clear();
        _load();
      } else {
        if (mounted) _snack('请求失败: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) _snack('请求失败: ${e.toString().replaceAll("Exception: ", "")}');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) _solve(imagePath: result.files.single.path!);
  }

  Future<void> _markMastered(String id) async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    await http.put(Uri.parse('${AppConfig.apiBaseUrl}/api/study/records/$id'), headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'}, body: json.encode({'status': '已掌握'}));
    _load();
  }

  Future<void> _genPractice() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final r = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/api/study/practice'), headers: {'Authorization': 'Bearer $tok'});
    if (r.statusCode == 200 && mounted) {
      final qs = (json.decode(r.body)['questions'] as List?) ?? [];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成 ${qs.length} 道练习题')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(backgroundColor: AppColors.bg(b), appBar: AppBar(title: const Text('📚 学习辅导')),
      body: Column(children: [
        Row(children: [_tb('解题', 0), _tb('记录', 1), _tb('分析', 2), _tb('同音字', 3)]),
        Expanded(child: _tab == 0 ? _solveTab(b) : _tab == 1 ? _recordsTab(b) : _tab == 2 ? _analysisTab(b) : const HomophonePage()),
      ]),
    );
  }

  Widget _tb(String l, int i) {
    final a = _tab == i;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _tab = i), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a ? AppColors.accent : Colors.transparent, width: 2))), child: Text(l, textAlign: TextAlign.center, style: TextStyle(color: a ? AppColors.accent : AppColors.textSecondary(Theme.of(context).brightness), fontWeight: a ? FontWeight.w600 : FontWeight.w400)))));
  }

  Widget _solveTab(Brightness b) => ListView(padding: const EdgeInsets.all(16), children: [
    TextField(controller: TextEditingController(text: _childName), onChanged: (v) => _childName = v, decoration: const InputDecoration(hintText: '孩子名字(可选)', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    TextField(controller: _qCtrl, maxLines: 4, decoration: InputDecoration(hintText: '输入题目...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: ElevatedButton.icon(onPressed: () => _solve(), icon: const Icon(Icons.send), label: const Text('提问'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)))),
      const SizedBox(width: 8),
      ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.camera_alt), label: const Text('拍照'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14))),
    ]),
    if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
    if (_result != null) ...[const SizedBox(height: 16), _resultCard(b)],
  ]);

  Widget _resultCard(Brightness b) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(_result!['subject'] ?? '', style: const TextStyle(color: AppColors.accent, fontSize: 12))), const SizedBox(width: 8), Text(_result!['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12))]),
    const SizedBox(height: 12),
    ...((_result!['steps'] as List?) ?? []).map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('💡', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(s.toString(), style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.5)))],))),
    if ((_result!['key_point'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 8), Text('🔑 ${_result!['key_point']}', style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w600))],
    const SizedBox(height: 8),
    Text('✅ ${_result!['answer']}', style: TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w600)),
  ]));

  Widget _recordsTab(Brightness b) {
    final filtered = _filterSubject.isEmpty ? _records : _records.where((r) => r['subject'] == _filterSubject).toList();
    if (_records.isEmpty) return Center(child: Text('还没有学习记录', style: TextStyle(color: AppColors.textSecondary(b))));
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [_fc('全部', ''), const SizedBox(width: 8), _fc('数学', '数学'), const SizedBox(width: 8), _fc('语文', '语文'), const SizedBox(width: 8), _fc('英语', '英语')])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (_, i) => _recordItem(filtered[i], b))),
    ]);
  }

  Widget _fc(String label, String value) {
    final a = _filterSubject == value;
    return GestureDetector(onTap: () => setState(() => _filterSubject = value), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: a ? AppColors.accent : AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: a ? Colors.white : AppColors.accent, fontSize: 12))));
  }

  Widget _recordItem(Map<String, dynamic> r, Brightness b) {
    final mastered = r['status'] == '已掌握';
    return GestureDetector(onTap: () => _showDetail(r, b), child: Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(10), border: mastered ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _sc(r['subject'] as String?).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(r['subject'] ?? '', style: TextStyle(fontSize: 11, color: _sc(r['subject'] as String?)))), const SizedBox(width: 8), Text(r['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)), const Spacer(), Text(mastered ? '✅' : '❌', style: const TextStyle(fontSize: 16))]),
        const SizedBox(height: 6),
        Text(r['question'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        Builder(builder: (_) { final a = _ans(r); if (a != null) return Padding(padding: const EdgeInsets.only(top: 3), child: Text('✅ $a', style: TextStyle(color: Colors.green, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)); return const SizedBox.shrink(); }),
        const SizedBox(height: 4),
        Row(children: [Text(_fmt(r['created_at']), style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)), const Spacer(), if (!mastered) GestureDetector(onTap: () => _markMastered(r['id'] as String), child: Text('标记已掌握', style: TextStyle(color: AppColors.accent, fontSize: 11)))]),
      ]),
    ));
  }

  void _showDetail(Map<String, dynamic> r, Brightness b) {
    Map<String, dynamic> a = {};
    try { a = json.decode(r['answer'] as String? ?? '{}') as Map<String, dynamic>; } catch (_) {}
    final steps = (a['steps'] as List?) ?? [];
    final kp = a['key_point'] as String? ?? '';
    final at = a['answer'] as String? ?? '';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final ws = <Widget>[
          Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21), borderRadius: BorderRadius.circular(10)), child: Text(r['question'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6))),
        ];
        if (steps.isNotEmpty) { ws.add(Text('💡 解题思路', style: TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w600))); for (final s in steps) ws.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.toString(), style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)))); }
        if (kp.isNotEmpty) ws.add(Text('🔑 $kp', style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w600)));
        if (at.isNotEmpty) ws.add(Text('✅ $at', style: TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w600)));
        return DraggableScrollableSheet(
          initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
          builder: (ctx2, sc) => Container(
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _sc(r['subject'] as String?).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(r['subject'] ?? '', style: TextStyle(fontSize: 12, color: _sc(r['subject'] as String?)))),
                const SizedBox(width: 8), Text(r['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
              ])),
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ws))),
            ]),
          ),
        );
      },
    );
  }
  Widget _analysisTab(Brightness b) {
    if (_analysis == null) return const Center(child: CircularProgressIndicator());
    final weak = (_analysis!['weak_points'] as List?) ?? [];
    final subjects = (_analysis!['subjects'] as Map<String, dynamic>?) ?? {};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📊 本周统计', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8), ...subjects.entries.map((e) => Text('${e.key}: ${e.value} 题', style: TextStyle(color: AppColors.text(b), fontSize: 14))),
        Text('共 ${_analysis!['total']} 道题', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
      ])),
      const SizedBox(height: 16),
      if (weak.isNotEmpty) ...[
        Text('⚠️ 薄弱点', style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...weak.map((w) => Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(8)), child: Text('${w['tag']}: 错 ${w['count']} 次', style: TextStyle(color: Colors.red.shade400)))),
        Text(_analysis!['suggestion'] ?? '', style: TextStyle(color: AppColors.accent, fontSize: 13)),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: _genPractice, icon: const Icon(Icons.auto_awesome), label: const Text('生成练习题'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white)),
      ],
    ]);
  }

  Color _sc(String? s) { switch (s) { case '数学': return const Color(0xFF3B82F6); case '语文': return const Color(0xFF10B981); case '英语': return const Color(0xFFF59E0B); default: return AppColors.accent; } }
  String? _ans(Map<String, dynamic> r) { try { final a = json.decode(r['answer'] as String? ?? '{}') as Map<String, dynamic>; final ans = a['answer'] as String?; return (ans != null && ans.isNotEmpty) ? ans : null; } catch (_) { return null; } }
  String _fmt(dynamic dt) { try { final d = DateTime.parse(dt as String); return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return ''; } }
}
