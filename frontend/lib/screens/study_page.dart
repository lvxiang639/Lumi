import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../config.dart';
import '../theme/app_colors.dart';
import '../services/routes.dart';
import 'homophone_page.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  int _tab = 0;
  final _qCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nameSearchCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _analysis;
  List<Map<String, dynamic>> _children = [];
  bool _solving = false;

  // Selection state
  String? _selectedChildId;
  String? _selectedChildName;
  String _nameSearch = '';

  // Filters
  String _filterSubject = '';
  String _filterStatus = '';
  bool _showNameDropdown = false;

  @override
  void initState() {
    super.initState();
    _load();
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) {
        setState(() {
          _nameSearch = '';
          _nameSearchCtrl.clear();
          _showNameDropdown = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _nameCtrl.dispose();
    _nameSearchCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final h = {'Authorization': 'Bearer $tok'};

    final cr = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/study/children'), headers: h);
    if (cr.statusCode == 200) {
      _children = (json.decode(cr.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    }

    final qp = <String, String>{};
    if (_selectedChildId != null) qp['child_id'] = _selectedChildId!;
    if (_filterSubject.isNotEmpty) qp['subject'] = _filterSubject;
    if (_filterStatus.isNotEmpty) qp['status'] = _filterStatus;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final rr = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/study/records${qs.isNotEmpty ? '?$qs' : ''}'), headers: h);
    if (rr.statusCode == 200) {
      _records = (json.decode(rr.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    }

    final aqp = _selectedChildId != null ? '?child_id=$_selectedChildId' : '';
    final ar = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/study/analysis$aqp'), headers: h);
    if (ar.statusCode == 200) _analysis = json.decode(ar.body);

    if (mounted) setState(() {});
  }

  // ── Solve ──

  Future<void> _solve({String? imagePath}) async {
    if (_qCtrl.text.trim().isEmpty && imagePath == null) {
      _snack('请输入题目或拍照');
      return;
    }
    setState(() => _solving = true);
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      var req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/study/solve'))
        ..headers['Authorization'] = 'Bearer $tok'
        ..fields['question'] = _qCtrl.text
        ..fields['child_name'] = _selectedChildName ?? _nameCtrl.text.trim();
      if (_selectedChildId != null) req.fields['child_id'] = _selectedChildId!;
      if (imagePath != null) req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      final resp = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        _result = json.decode(resp.body);
        _qCtrl.clear();
        _load();
      } else {
        final body = json.decode(resp.body);
        if (mounted) _snack(body['detail'] ?? '请求失败');
      }
    } catch (e) {
      if (mounted) _snack('请求失败');
    }
    if (mounted) setState(() => _solving = false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  // ── Child Selection ──

  void _selectChild(String? id, String name) {
    setState(() {
      _selectedChildId = id;
      _selectedChildName = name;
      _nameCtrl.text = name;
      _nameSearch = '';
      _nameSearchCtrl.clear();
      _showNameDropdown = false;
      _nameFocus.unfocus();
    });
    _load();
  }

  void _clearChild() {
    setState(() {
      _selectedChildId = null;
      _selectedChildName = null;
      _nameCtrl.clear();
      _nameSearch = '';
      _nameSearchCtrl.clear();
    });
    _load();
  }

  // ── Records Actions ──

  Future<void> _deleteRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条学习记录吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final resp = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/api/study/records/$id'),
      headers: {'Authorization': 'Bearer $tok'},
    );
    if (resp.statusCode == 200) {
      _snack('已删除');
      _load();
    }
  }

  Future<void> _markMastered(String id) async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/study/records/$id'),
      headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'},
      body: json.encode({'status': '已掌握'}),
    );
    _load();
  }

  Future<void> _genPractice() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final fields = <String, String>{};
    if (_selectedChildId != null) fields['child_id'] = _selectedChildId!;
    final r = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/study/practice'),
      headers: {'Authorization': 'Bearer $tok'},
      body: fields,
    );
    if (r.statusCode == 200 && mounted) {
      final qs = (json.decode(r.body)['questions'] as List?) ?? [];
      _snack('已生成 ${qs.length} 道练习题');
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) _solve(imagePath: result.files.single.path!);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () => setState(() => _showNameDropdown = false),
      child: Scaffold(
        backgroundColor: AppColors.bg(b),
        appBar: AppBar(
          title: const Text('📚 学习辅导'),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        body: Column(children: [
          _tabBar(b),
          Expanded(child: _tabBody(b)),
        ]),
      ),
    );
  }

  Widget _tabBar(Brightness b) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(b),
        border: Border(bottom: BorderSide(color: AppColors.border(b).withValues(alpha: 0.3))),
      ),
      child: Row(children: [
        _tabBtn('💡 解题', 0),
        _tabBtn('📋 记录', 1),
        _tabBtn('📊 分析', 2),
        _tabBtn('🎯 专项', 3),
      ]),
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    final b = Theme.of(context).brightness;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2.5)),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: active ? AppColors.accent : AppColors.textSecondary(b),
          fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    ));
  }

  Widget _tabBody(Brightness b) {
    switch (_tab) {
      case 0: return _solveTab(b);
      case 1: return _recordsTab(b);
      case 2: return _analysisTab(b);
      case 3: return _specializedTab(b);
      default: return const SizedBox.shrink();
    }
  }

  // ── Solve Tab ──

  Widget _solveTab(Brightness b) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Name selector
        _nameSelector(b),
        const SizedBox(height: 12),
        // Question input
        TextField(
          controller: _qCtrl,
          maxLines: 4,
          style: TextStyle(color: AppColors.text(b), fontSize: 15),
          decoration: InputDecoration(
            hintText: '输入题目...',
            hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.card(b),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(b).withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(b).withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(children: [
          Expanded(child: _btn('提问', Icons.send, () => _solve(), primary: true, loading: _solving)),
          const SizedBox(width: 10),
          _btn('拍照', Icons.camera_alt, _pickImage, primary: false),
        ]),
        // Loading
        if (_solving) const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()),
        // Result
        if (_result != null) ...[const SizedBox(height: 16), _resultCard(b)],
      ],
    );
  }

  Widget _nameSelector(Brightness b) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // Selected child chip + input
      Container(
        decoration: BoxDecoration(
          color: AppColors.card(b),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _showNameDropdown ? AppColors.accent : AppColors.border(b).withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: [
          const Padding(padding: EdgeInsets.only(left: 10), child: Text('👤', style: TextStyle(fontSize: 16))),
          Expanded(child: TextField(
            controller: _nameSearchCtrl,
            focusNode: _nameFocus,
            onChanged: (v) => setState(() => _nameSearch = v.trim().toLowerCase()),
            onTap: () => setState(() { _nameSearch = ''; _nameSearchCtrl.clear(); _showNameDropdown = true; }),
            style: TextStyle(color: AppColors.text(b), fontSize: 14),
            decoration: InputDecoration(
              hintText: _selectedChildName ?? '选择或输入孩子名字',
              hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.4), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              isDense: true,
              suffixIcon: _selectedChildId != null
                  ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearChild, padding: EdgeInsets.zero, splashRadius: 16)
                  : _children.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 22) : null,
            ),
          )),
        ]),
      ),

      // Dropdown
      if (_showNameDropdown && _children.isNotEmpty) _nameDropdown(b),
    ]);
  }

  Widget _nameDropdown(Brightness b) {
    final query = _nameSearch;
    var filtered = _children.where((c) {
      final name = (c['name'] as String).toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    final exactMatch = _children.any((c) => (c['name'] as String).toLowerCase() == query);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(b)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            if (filtered.isNotEmpty)
              ...filtered.map((c) => _childOption(c, b))
            else if (query.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.search_off, size: 20, color: Colors.grey),
                title: Text('没有匹配 "$query" 的孩子', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            if (query.isNotEmpty && !exactMatch)
              ListTile(
                dense: true,
                leading: const Icon(Icons.add_circle, color: AppColors.accent, size: 20),
                title: Text('新增 "$query"', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w500)),
                onTap: () => _selectChild(null, query),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _childOption(Map<String, dynamic> c, Brightness b) {
    final cid = c['id'] as String;
    final name = c['name'] as String;
    final grade = c['grade'] as String? ?? '';
    final isSelected = cid == _selectedChildId;

    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: AppColors.accent.withValues(alpha: 0.06),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: isSelected ? AppColors.accent.withValues(alpha: 0.15) : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        child: Text(grade.isNotEmpty ? grade[0] : name[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? AppColors.accent : const Color(0xFF8B5CF6))),
      ),
      title: Row(children: [
        Text(name, style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        if (grade.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(3)), child: Text(grade, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10))),
        ],
      ]),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20) : const Icon(Icons.radio_button_unchecked, size: 20, color: Colors.grey),
      onTap: () => _selectChild(cid, name),
    );
  }

  // ── Result Card ──

  Widget _resultCard(Brightness b) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card(b),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _sc(_result!['subject']).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(_result!['subject'] ?? '', style: TextStyle(color: _sc(_result!['subject']), fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Expanded(child: Text(_result!['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12))),
      ]),
      const SizedBox(height: 14),
      ...((_result!['steps'] as List?) ?? []).map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.toString(), style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.5))),
        ]),
      )),
      if ((_result!['key_point'] as String?)?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Text('🔑', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(_result!['key_point']!, style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w600)))])),
      ],
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Text('✅', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(_result!['answer'] ?? '', style: const TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w600)))])),
    ]),
  );

  // ── Records Tab ──

  Widget _recordsTab(Brightness b) {
    if (_records.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book_outlined, size: 48, color: AppColors.textSecondary(b).withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Text('还没有学习记录', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 14)),
        const SizedBox(height: 4),
        Text('去解题 Tab 添加第一条记录吧', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 12)),
      ]));
    }

    return Column(children: [
      // Filter chips
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _chip('全部孩子', _selectedChildId == null, () { _selectedChildId = null; _selectedChildName = null; _nameCtrl.clear(); _load(); }),
          const SizedBox(width: 6),
          ..._children.map((c) => _chip(c['name'] as String, _selectedChildId == c['id'], () {
            _selectChild(c['id'] as String, c['name'] as String);
          })),
          const SizedBox(width: 14),
          _chip('全部科目', _filterSubject.isEmpty, () => setState(() { _filterSubject = ''; _load(); })),
          ...['数学', '语文', '英语'].map((s) => _chip(s, _filterSubject == s, () => setState(() { _filterSubject = s; _load(); }))),
          const SizedBox(width: 14),
          _chip('全部状态', _filterStatus.isEmpty, () => setState(() { _filterStatus = ''; _load(); })),
          _chip('未掌握', _filterStatus == '未掌握', () => setState(() { _filterStatus = '未掌握'; _load(); })),
          _chip('已掌握', _filterStatus == '已掌握', () => setState(() { _filterStatus = '已掌握'; _load(); })),
        ])),
      ),
      const SizedBox(height: 4),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: _records.length,
        itemBuilder: (_, i) => _recordCard(_records[i], b),
      )),
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.accent, fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> r, Brightness b) {
    final mastered = r['status'] == '已掌握';
    final childLabel = (r['child_name'] as String?) ?? '';
    final subject = r['subject'] as String? ?? '';

    return Dismissible(
      key: Key(r['id'] as String),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这条学习记录吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
      onDismissed: (_) => _deleteRecord(r['id'] as String),
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
      child: GestureDetector(
        onTap: () => _showDetail(r, b),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card(b),
            borderRadius: BorderRadius.circular(12),
            border: mastered ? Border.all(color: Colors.green.withValues(alpha: 0.2)) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (childLabel.isNotEmpty) ...[
                _badge('👤 $childLabel', const Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
              ],
              _badge(subject, _sc(subject)),
              const SizedBox(width: 6),
              Expanded(child: Text(r['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11), overflow: TextOverflow.ellipsis)),
              Icon(mastered ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: mastered ? Colors.green : AppColors.textSecondary(b).withValues(alpha: 0.4)),
            ]),
            const SizedBox(height: 8),
            Text(r['question'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            Builder(builder: (_) {
              final a = _ans(r);
              if (a != null) return Padding(padding: const EdgeInsets.only(top: 4), child: Text('✅ $a', style: const TextStyle(color: Colors.green, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis));
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 6),
            Row(children: [
              Text(_fmt(r['created_at']), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 10)),
              const Spacer(),
              if (!mastered)
                GestureDetector(
                  onTap: () => _markMastered(r['id'] as String),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('标记已掌握', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500))),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
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
        final ws = <Widget>[];
        if ((r['child_name'] as String?)?.isNotEmpty == true) {
          ws.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('👤 ${r['child_name']}', style: TextStyle(color: const Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.w500))));
        }
        ws.add(Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21), borderRadius: BorderRadius.circular(12)), child: Text(r['question'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.6))));
        if (steps.isNotEmpty) { ws.add(const SizedBox(height: 16)); ws.add(Text('💡 解题思路', style: TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w600))); for (final s in steps) ws.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.toString(), style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)))); }
        if (kp.isNotEmpty) { ws.add(const SizedBox(height: 12)); ws.add(Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Text('🔑', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(kp, style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w600)))]))); }
        if (at.isNotEmpty) { ws.add(const SizedBox(height: 12)); ws.add(Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Text('✅', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(at, style: const TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w600)))]))); }
        return DraggableScrollableSheet(initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
          builder: (ctx2, sc) => Container(
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                _badge(r['subject'] ?? '', _sc(r['subject'])),
                const SizedBox(width: 8),
                Text(r['tags'] ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
                const Spacer(),
                Text(_fmt(r['created_at']), style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 11)),
              ])),
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ws))),
            ]),
          ),
        );
      },
    );
  }

  // ── Analysis Tab ──

  Widget _analysisTab(Brightness b) {
    if (_analysis == null) return const Center(child: CircularProgressIndicator());
    final children = (_analysis!['children'] as List?) ?? [];
    final overall = _analysis!['overall'] as Map<String, dynamic>? ?? {};

    if (children.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.analytics_outlined, size: 56, color: AppColors.textSecondary(b).withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text('还没有学习记录', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('去解题 Tab 开始辅导吧', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 13)),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        _overallCard(overall, b),
        const SizedBox(height: 14),
        ...children.map((c) => _childAnalysisCard(c as Map<String, dynamic>, b)),
      ],
    );
  }

  Widget _overallCard(Map<String, dynamic> overall, Brightness b) {
    final total = overall['total'] as int? ?? 0;
    final mastered = overall['mastered'] as int? ?? 0;
    final rate = (overall['mastery_rate'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📊 本周学习概览', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statColumn('$total', '总题数'),
          _statColumn('${(rate * 100).toInt()}%', '掌握率'),
          _statColumn('$mastered', '已掌握'),
        ]),
      ]),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
    ]);
  }

  Widget _childAnalysisCard(Map<String, dynamic> c, Brightness b) {
    final name = c['child_name'] as String? ?? '未命名';
    final grade = c['grade'] as String? ?? '';
    final total = c['total'] as int? ?? 0;
    final mastered = c['mastered'] as int? ?? 0;
    final rate = (c['mastery_rate'] as num?)?.toDouble() ?? 0.0;
    final bySubject = (c['by_subject'] as Map<String, dynamic>?) ?? {};
    final weakPoints = (c['weak_points'] as List?) ?? [];
    final suggestion = c['ai_suggestion'] as String? ?? '';
    final childId = c['child_id'] as String? ?? '';

    if (total == 0 && suggestion.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(b).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12), child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600)),
                if (grade.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(grade, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10))),
                ],
              ]),
              Text('$total题 · 掌握 ${(rate * 100).toInt()}%', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$mastered', style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.w700)),
              Text('/ $total 题', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)),
            ]),
          ]),
        ),

        if (total > 0) ...[
          const SizedBox(height: 12),
          // Subject breakdown
          if (bySubject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: bySubject.entries.map((e) {
                final subColor = _sc(e.key);
                return Expanded(child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: subColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text(e.key, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${e.value}', style: TextStyle(color: subColor, fontSize: 22, fontWeight: FontWeight.w700)),
                    Text('题', style: TextStyle(color: subColor.withValues(alpha: 0.6), fontSize: 10)),
                  ]),
                ));
              }).toList()),
            ),
        ],

        // Weak points
        if (weakPoints.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('⚠️ 薄弱知识点', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          ...weakPoints.take(5).map((dynamic w) {
            final tag = (w['tag'] as String?) ?? '';
            final count = (w['count'] as int?) ?? 0;
            final firstCount = ((weakPoints.first as Map)['count'] as int?) ?? 1;
            final ratio = firstCount > 0 ? count / firstCount : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(children: [
                SizedBox(width: 72, child: Text(tag, style: TextStyle(color: AppColors.text(b), fontSize: 12), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: Colors.red.withValues(alpha: 0.08), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444))))),
                const SizedBox(width: 8),
                SizedBox(width: 28, child: Text('${count}次', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            );
          }),
        ],

        // AI suggestion
        if (suggestion.isNotEmpty && suggestion != '暂无') ...[
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(suggestion, style: TextStyle(color: AppColors.accent, fontSize: 12, height: 1.5))),
            ]),
          ),
        ],

        // Generate practice button
        if (weakPoints.isNotEmpty && childId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () { _selectedChildId = childId; _genPractice(); },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text('为 $name 生成练习题'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ),

        if (total == 0) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text('本周还没有做题记录', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ── Specialized Tab ──

  Widget _specializedTab(Brightness b) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _specializedItem(
        icon: Icons.hearing, color: const Color(0xFF7C3AED),
        title: '同音字组词闯关', desc: '根据拼音写出同音字并组词，每轮5道题',
        onTap: () => Navigator.push(context, slideRoute(const HomophonePage())),
      ),
    ]);
  }

  Widget _specializedItem({required IconData icon, required Color color, required String title, required String desc, required VoidCallback onTap}) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(14),
          child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(14)), child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(desc, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, height: 1.3))])), Icon(Icons.chevron_right, color: AppColors.textSecondary(b), size: 20),
          ])),
        ),
      ),
    );
  }

  // ── Button Helpers ──

  Widget _btn(String label, IconData icon, VoidCallback onTap, {required bool primary, bool loading = false}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon, size: 18),
        label: Text(loading ? '处理中...' : label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? AppColors.accent : null,
          foregroundColor: primary ? Colors.white : AppColors.text(Theme.of(context).brightness),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: primary ? 2 : 0,
        ),
      ),
    );
  }

  // ── Color helpers ──

  Color _sc(dynamic s) {
    final str = s?.toString() ?? '';
    switch (str) {
      case '数学': return const Color(0xFF3B82F6);
      case '语文': return const Color(0xFF10B981);
      case '英语': return const Color(0xFFF59E0B);
      default: return AppColors.accent;
    }
  }

  String? _ans(Map<String, dynamic> r) {
    try {
      final a = json.decode(r['answer'] as String? ?? '{}') as Map<String, dynamic>;
      final ans = a['answer'] as String?;
      return (ans != null && ans.isNotEmpty) ? ans : null;
    } catch (_) {
      return null;
    }
  }

  String _fmt(dynamic dt) {
    try {
      final d = DateTime.parse(dt as String);
      return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
