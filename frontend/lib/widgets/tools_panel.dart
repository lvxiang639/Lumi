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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _surface, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textSecondary),
          onPressed: widget.onClose ?? () => Navigator.pop(context)),
      title: const Text('助手工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
      centerTitle: true,
    ),
    body: Row(children: [
      Container(width: 68, decoration: const BoxDecoration(color: _surface, border: Border(right: BorderSide(color: _border, width: 1))),
        child: Column(children: [
          const SizedBox(height: 8),
          ...List.generate(_menuItems.length, (i) {
            final active = i == _selectedIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _menuItems[i].color.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Icon(_menuItems[i].icon, size: 22, color: active ? _menuItems[i].color : _textSecondary),
                  const SizedBox(height: 3),
                  Text(_menuItems[i].label, style: TextStyle(fontSize: 10, color: active ? _menuItems[i].color : _textSecondary)),
                ]),
              ),
            );
          }),
        ]),
      ),
      Expanded(child: IndexedStack(index: _selectedIndex, children: const [
        _CalendarContent(), _ExpenseContent(), _NotesContent(), _OcrContent(),
        _MoodContent(), _ConversionContent(), _EmailContent(),
      ])),
    ]),
  );
}

class _MenuItem { final IconData icon; final String label; final Color color; const _MenuItem(this.icon, this.label, this.color); }

// ── Calendar ──
class _CalendarContent extends StatelessWidget {
  const _CalendarContent();
  @override
  Widget build(BuildContext context) => Consumer<CalendarProvider>(builder: (c, p, _) {
    if (p.loading) return const Center(child: CircularProgressIndicator(color: _accent));
    if (p.events.isEmpty) return const Center(child: Text('暂无提醒', style: TextStyle(color: _textSecondary)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16,20,16,12), child: Row(children: [
        Icon(Icons.calendar_month_rounded, size:20, color:Color(0xFFF59E0B)), SizedBox(width:8),
        Text('日历提醒', style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:_textPrimary))])),
      Expanded(child: ListView.builder(itemCount: p.events.length, padding: const EdgeInsets.symmetric(horizontal:8),
        itemBuilder: (_, i) { final e = p.events[i]; final dt = e.time;
          return Container(margin: const EdgeInsets.symmetric(horizontal:8, vertical:3),
            decoration: BoxDecoration(color: _cardBg.withValues(alpha:0.6), borderRadius: BorderRadius.circular(10)),
            child: ListTile(leading: const Icon(Icons.event, color: Color(0xFFF59E0B), size:22),
              title: Text(e.title, style: const TextStyle(color: _textPrimary, fontSize:14)),
              subtitle: Text('${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(color: _textSecondary, fontSize:12)),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, size:18, color:Colors.redAccent),
                  onPressed: () => p.deleteEvent(e.id)),
            ));
        })),
    ]);
  });
}

// ── Expense ──
class _ExpenseContent extends StatefulWidget { const _ExpenseContent(); @override State<_ExpenseContent> createState() => _ExpenseContentState(); }
class _ExpenseContentState extends State<_ExpenseContent> {
  String _period = 'month';
  void _edit(BuildContext c, ExpenseProvider p, String id, double amt, String cat, String rem) {
    final a = TextEditingController(text: amt.abs().toStringAsFixed(2));
    final ct = TextEditingController(text: cat), rk = TextEditingController(text: rem);
    showDialog(context: c, builder: (ctx) => AlertDialog(backgroundColor: _surface,
      title: const Text('编辑记录', style: TextStyle(color: _textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: a, keyboardType: TextInputType.number, style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(labelText: '金额', labelStyle: TextStyle(color: _textSecondary))),
        TextField(controller: ct, style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(labelText: '分类', labelStyle: TextStyle(color: _textSecondary))),
        TextField(controller: rk, style: const TextStyle(color: _textPrimary),
            decoration: const InputDecoration(labelText: '备注', labelStyle: TextStyle(color: _textSecondary))),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textSecondary))),
        TextButton(onPressed: () { final na = double.tryParse(a.text) ?? amt;
          p.update(id, {'amount': amt < 0 ? -na : na, 'category': ct.text, 'remark': rk.text}); Navigator.pop(ctx); },
            child: const Text('保存', style: TextStyle(color: _accent)))]));
  }
  @override
  Widget build(BuildContext c) => Consumer<ExpenseProvider>(builder: (c, p, _) {
    if (p.loading) return const Center(child: CircularProgressIndicator(color: _accent));
    final s = _period == 'week' ? p.weeklyStats : p.stats;
    final total = (s?['total_expense'] as num?)?.toDouble() ?? 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16,20,16,8), child: Row(children: [
        Icon(Icons.account_balance_wallet_rounded, size:20, color:Color(0xFF10B981)), SizedBox(width:8),
        Text('记账', style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:_textPrimary))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Row(children: [
        _chip('周','week'), const SizedBox(width:8), _chip('月','month'), const Spacer(),
        Text('${_period=="week"?"本周":"本月"}: ¥${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize:14, fontWeight:FontWeight.w600, color:_textPrimary))])),
      if (s != null && s['by_category'] != null) (() {
        final chips = (s['by_category'] as Map).entries.map<Widget>((e) => Chip(
          label: Text('${e.key} ¥${(e.value as num).toStringAsFixed(0)}', style: const TextStyle(fontSize:11, color:_textSecondary)),
          backgroundColor: _cardBg, side: const BorderSide(color: _border),
        )).toList();
        return Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:6),
          child: Wrap(spacing:6, runSpacing:4, children: chips));
      })(),
      const Divider(color: _border, height:1),
      if (p.records.isEmpty) const Expanded(child: Center(child: Text('暂无记录', style: TextStyle(color: _textSecondary))))
      else Expanded(child: ListView.builder(itemCount: p.records.length, padding: const EdgeInsets.symmetric(horizontal:8),
        itemBuilder: (_, i) { final r = p.records[i]; final isExp = r.amount > 0;
          return Container(margin: const EdgeInsets.symmetric(horizontal:8, vertical:2),
            decoration: BoxDecoration(color: _cardBg.withValues(alpha:0.6), borderRadius: BorderRadius.circular(10)),
            child: ListTile(leading: CircleAvatar(backgroundColor: isExp ? Colors.red.withValues(alpha:0.2) : Colors.green.withValues(alpha:0.2), radius:16,
              child: Text(r.category, style: TextStyle(fontSize:10, color: isExp ? Colors.redAccent : Colors.greenAccent))),
              title: Text('${isExp ? "-" : "+"}¥${r.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(fontWeight:FontWeight.w600, color: isExp ? Colors.redAccent : Colors.greenAccent, fontSize:14)),
              subtitle: r.remark.isNotEmpty ? Text(r.remark, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontSize:11, color:_textSecondary)) : null,
              trailing: Row(mainAxisSize:MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size:16, color:_textSecondary), onPressed:()=>_edit(c,p,r.id,r.amount,r.category,r.remark)),
                IconButton(icon: const Icon(Icons.delete_outline, size:16, color:Colors.redAccent), onPressed:()=>p.delete(r.id))])));
        })),
    ]);
  });
  Widget _chip(String l, String period) { final a = _period == period;
    return GestureDetector(onTap: ()=>setState(()=>_period=period),
      child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4),
        decoration: BoxDecoration(color: a ? const Color(0xFF10B981).withValues(alpha:0.2) : _cardBg,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: a ? const Color(0xFF10B981).withValues(alpha:0.4) : _border)),
        child: Text(l, style: TextStyle(fontSize:12, color: a ? const Color(0xFF10B981) : _textSecondary)))); }
}

// ── Notes ──
class _NotesContent extends StatefulWidget { const _NotesContent(); @override State<_NotesContent> createState() => _NotesContentState(); }
class _NotesContentState extends State<_NotesContent> {
  List<Map<String, dynamic>> _notes = []; bool _loading = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(()=>_loading=true);
    try { final d = await ApiClient().get('/api/notes?note_type=note'); setState(()=>_notes=(d['items'] as List?)?.cast<Map<String,dynamic>>()??[]); } catch(_){} setState(()=>_loading=false); }
  Future<void> _add() async {
    final t=TextEditingController(),c=TextEditingController();
    await showDialog(context:context, builder:(ctx)=>AlertDialog(backgroundColor:_surface,
      title:const Text('新建笔记', style:TextStyle(color:_textPrimary)),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:t,style:const TextStyle(color:_textPrimary),decoration:const InputDecoration(hintText:'标题',hintStyle:TextStyle(color:_textSecondary))),
        TextField(controller:c,maxLines:4,style:const TextStyle(color:_textPrimary),decoration:const InputDecoration(hintText:'内容',hintStyle:TextStyle(color:_textSecondary)))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消',style:TextStyle(color:_textSecondary))),
        TextButton(onPressed:()async{if(c.text.trim().isEmpty)return;
          await ApiClient().post('/api/notes',body:{'title':t.text,'content':c.text,'note_type':'note'});Navigator.pop(ctx);_load();},
          child:const Text('保存',style:TextStyle(color:_accent)))]));
  }
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.fromLTRB(16,20,16,8),child:Row(children:[
      const Icon(Icons.edit_note_rounded,size:20,color:Color(0xFF06B6D4)),const SizedBox(width:8),
      const Text('笔记',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:_textPrimary)),
      const Spacer(),IconButton(icon:const Icon(Icons.add,color:_accent),onPressed:_add)])),
    if(_loading)const Center(child:CircularProgressIndicator(color:_accent))
    else if(_notes.isEmpty)const Expanded(child:Center(child:Text('暂无笔记',style:TextStyle(color:_textSecondary))))
    else Expanded(child:ListView.builder(itemCount:_notes.length,padding:const EdgeInsets.symmetric(horizontal:8),
      itemBuilder:(_,i){final n=_notes[i];
        return Container(margin:const EdgeInsets.symmetric(horizontal:8,vertical:3),
          decoration:BoxDecoration(color:_cardBg.withValues(alpha:0.6),borderRadius:BorderRadius.circular(10)),
          child:ListTile(title:Text(n['title']as String? ?? '',style:const TextStyle(color:_textPrimary,fontSize:14)),
            subtitle:Text((n['content']as String? ?? ''),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_textSecondary,fontSize:12)),
            trailing:IconButton(icon:const Icon(Icons.delete_outline,size:18,color:Colors.redAccent),
                onPressed:()async{await ApiClient().delete('/api/notes/${n['id']}');_load();})));}))
  ]);
}

// ── OCR ──
class _OcrContent extends StatefulWidget { const _OcrContent(); @override State<_OcrContent> createState() => _OcrContentState(); }
class _OcrContentState extends State<_OcrContent> {
  String _result = ''; bool _loading = false;
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
        final t = d['type'] as String? ?? 'text';
        final tl = {'receipt': '🧾 发票', 'card': '👤 名片', 'text': '📄 文字'}[t] ?? '📄';
        setState(() { _loading = false; _result = '$tl\n${d['text']}'; });
      } else { setState(() { _loading = false; _result = '识别失败'; }); }
    } catch (e) { setState(() { _loading = false; _result = '出错: $e'; }); }
  }
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Row(children: [Icon(Icons.document_scanner_rounded, size: 20, color: Color(0xFF8B5CF6)), SizedBox(width: 8),
      Text('图片 OCR', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary))]),
    const SizedBox(height: 4),
    const Text('拍照识别文字，支持发票、名片、普通文字', style: TextStyle(fontSize: 12, color: _textSecondary)),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: _loading ? null : _scan,
      icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt),
      label: Text(_loading ? '识别中...' : '拍照 / 选择图片'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    if (_result.isNotEmpty) Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10)),
      child: SelectableText(_result, style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.6))),
  ]));
}

// ── Mood ──
class _MoodContent extends StatefulWidget { const _MoodContent(); @override State<_MoodContent> createState() => _MoodContentState(); }
class _MoodContentState extends State<_MoodContent> {
  final _emotions = const [
    ('😊', 'joy'), ('😢', 'sad'), ('😠', 'angry'),
    ('😌', 'calm'), ('😲', 'surprised'), ('😟', 'worried'),
  ];
  List<Map<String, dynamic>> _moods = [];
  Map<String, dynamic> _stats = {};
  bool _loading = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => _loading = true);
    try { final a = ApiClient();
      final md = await a.get('/api/notes/moods'); _moods = (md['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final sd = await a.get('/api/notes/moods/stats?period=week'); _stats = sd['by_emotion'] as Map<String, dynamic>? ?? {};
    } catch (_) {} setState(() => _loading = false); }
  Future<void> _log(String e) async { await ApiClient().post('/api/notes/moods', body: {'emotion': e, 'intensity': 1.0}); _load(); }
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 8), child: Row(children: [
      Icon(Icons.mood_rounded, size: 20, color: Color(0xFFEC4899)), SizedBox(width: 8),
      Text('心情日记', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8,
      children: _emotions.map((e) => GestureDetector(onTap: () => _log(e.$2), child: Chip(
        avatar: Text(e.$1, style: const TextStyle(fontSize: 18)),
        label: Text(e.$2, style: const TextStyle(fontSize: 11, color: _textSecondary)),
        backgroundColor: _cardBg, side: const BorderSide(color: _border),
      ))).toList())),
    if (_stats.isNotEmpty) (() {
      final statChips = _stats.entries
        .where((e) => (e.value as int) > 0)
        .map((e) {
          final emoji = _emotions.firstWhere((x) => x.$2 == e.key, orElse: () => ('❓', '')).$1;
          return Chip(label: Text('$emoji ×${e.value}', style: const TextStyle(fontSize: 12, color: _textSecondary)), backgroundColor: _cardBg);
        }).toList();
      return Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, runSpacing: 4, children: statChips));
    })(),
    const Divider(color: _border),
    if (_loading) const Center(child: CircularProgressIndicator(color: _accent))
    else if (_moods.isEmpty) const Expanded(child: Center(child: Text('暂无记录', style: TextStyle(color: _textSecondary))))
    else Expanded(child: ListView.builder(itemCount: _moods.length, padding: const EdgeInsets.symmetric(horizontal: 8),
      itemBuilder: (_, i) {
        final m = _moods[i];
        final emo = _emotions.firstWhere((e) => e.$2 == (m['emotion'] ?? ''), orElse: () => ('❓', ''));
        final dt = (m['created_at'] as String? ?? '');
        final dtShort = dt.length >= 16 ? dt.substring(0, 16) : dt;
        return ListTile(
          leading: Text(emo.$1, style: const TextStyle(fontSize: 22)),
          title: Text(m['emotion'] as String? ?? '', style: const TextStyle(color: _textPrimary, fontSize: 14)),
          subtitle: Text(dtShort, style: const TextStyle(fontSize: 11, color: _textSecondary)),
        );
      })),
  ]);
}

// ── Conversion ──
class _ConversionContent extends StatefulWidget { const _ConversionContent(); @override State<_ConversionContent> createState() => _ConversionContentState(); }
class _ConversionContentState extends State<_ConversionContent> {
  String? _sf, _of; bool _cvt = false; String _status = ''; List<Map<String, dynamic>> _files = []; bool _lf = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => _lf = true);
    try { final t = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/tools/files'), headers: {'Authorization': 'Bearer $t'});
      if (r.statusCode == 200) { final d = jsonDecode(r.body) as Map<String, dynamic>; setState(() => _files = (d['items'] as List?)?.cast<Map<String, dynamic>>() ?? []); }
    } catch (_) {} setState(() => _lf = false); }
  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'pdf']);
    if (r != null && r.files.single.path != null) { final n = r.files.single.name; final e = n.split('.').last.toLowerCase();
      setState(() { _sf = r.files.single.path; _of = e == 'pdf' ? 'docx' : 'pdf'; _status = '已选择: $n'; }); }
  }
  Future<void> _convert() async { if (_sf == null || _of == null) return; setState(() { _cvt = true; _status = '转换中...'; });
    try { final t = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/tools/convert?target=$_of'))
        ..headers['Authorization'] = 'Bearer $t'..files.add(await http.MultipartFile.fromPath('file', _sf!));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) { final d = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() { _cvt = false; _status = '✅ ${d['target_name']}'; _sf = null; }); _load(); }
      else { setState(() { _cvt = false; _status = '转换失败'; }); }
    } catch (e) { setState(() { _cvt = false; _status = '出错: $e'; }); }
  }
  Future<void> _dl(String url, String name) async {
    try { final r = await http.get(Uri.parse(url)); if (r.statusCode == 200) {
        final f = File('${(await getTemporaryDirectory()).path}/$name'); await f.writeAsBytes(r.bodyBytes);
        if (Platform.isMacOS || Platform.isIOS) await Process.run('open', [f.path]); }
    } catch (_) {}
  }
  String _fs(int b) { if (b < 1024) return '$b B'; if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB'; return '${(b / 1048576).toStringAsFixed(1)} MB'; }
  @override
  Widget build(BuildContext c) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Row(children: [Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF6366F1)), SizedBox(width: 8),
      Text('文件处理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary))]),
    const SizedBox(height: 4), const Text('Word ↔ PDF 互相转换', style: TextStyle(fontSize: 13, color: _textSecondary)), const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file, color: _accent),
      label: const Text('选择文件 (.docx / .pdf)', style: TextStyle(color: _accent)),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: _accent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    if (_sf != null) ... [const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_sf!.split('.').last.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: _accent)),
        Text(_of == 'pdf' ? '📄 PDF' : '📝 Word', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary))]),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: _cvt ? null : _convert,
        icon: _cvt ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
        label: Text(_cvt ? '转换中...' : '开始转换'),
        style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))],
    if (_status.isNotEmpty) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _status.startsWith('✅') ? const Color(0xFF10B981).withValues(alpha: 0.1) : _cardBg, borderRadius: BorderRadius.circular(8)),
      child: Text(_status, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _status.startsWith('✅') ? const Color(0xFF10B981) : _textSecondary))),
    const SizedBox(height: 20), const Divider(color: _border), const SizedBox(height: 8),
    Row(children: [const Text('转换历史', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)), const Spacer(),
      IconButton(icon: const Icon(Icons.refresh, size: 18, color: _textSecondary), onPressed: _load)]),
    if (_lf) const Center(child: CircularProgressIndicator(color: _accent))
    else if (_files.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('暂无文件', style: TextStyle(color: _textSecondary, fontSize: 13))))
    else ...List.generate(_files.length, (i) { final f = _files[i]; final n = f['target_name'] as String? ?? ''; final s = f['file_size'] as int? ?? 0; final u = f['download_url'] as String? ?? ''; final dt = f['created_at'] as String? ?? '';
      return ListTile(leading: Icon(n.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description, color: n.endsWith('.pdf') ? Colors.redAccent : Colors.blueAccent, size: 22),
        title: Text(n, style: const TextStyle(color: _textPrimary, fontSize: 13)),
        subtitle: Text('${_fs(s)} · ${dt.length >= 16 ? dt.substring(0, 16) : dt}', style: const TextStyle(fontSize: 11, color: _textSecondary)),
        trailing: IconButton(icon: const Icon(Icons.download, size: 18, color: _accent), onPressed: u.isNotEmpty ? () => _dl(u, n) : null)); }),
  ]));
}

// ── Email ──
class _EmailContent extends StatefulWidget { const _EmailContent(); @override State<_EmailContent> createState() => _EmailContentState(); }
class _EmailContentState extends State<_EmailContent> {
  bool _sending = false; String _status = ''; List<Map<String, dynamic>> _list = []; bool _ll = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => _ll = true);
    try { final d = await ApiClient().get('/api/conversations/sent-emails'); setState(() => _list = (d['items'] as List?)?.cast<Map<String, dynamic>>() ?? []); } catch (_) {} setState(() => _ll = false); }
  Future<void> _send() async {
    final cid = context.read<ChatProvider>().conversationId; if (cid == null) { setState(() => _status = '请先开始对话'); return; }
    setState(() { _sending = true; _status = '发送中...'; });
    try { await ApiClient().post('/api/conversations/$cid/email-summary'); setState(() { _sending = false; _status = '✅ 已发送'; }); _load(); }
    on ApiException catch (e) { setState(() => _sending = false); if (e.statusCode == 400 && e.body.contains('邮箱')) _setupEmail(); else _status = '发送失败'; }
    catch (_) { setState(() { _sending = false; _status = '发送失败'; }); }
  }
  void _setupEmail() { final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: _surface, title: const Text('设置邮箱', style: TextStyle(color: _textPrimary)),
      content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: _textPrimary),
          decoration: const InputDecoration(hintText: '输入邮箱地址', hintStyle: TextStyle(color: _textSecondary))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textSecondary))),
        TextButton(onPressed: () async { final e = c.text.trim(); if (e.isEmpty) return;
          try { await ApiClient().put('/api/auth/profile', body: {'email': e}); if (ctx.mounted) Navigator.pop(ctx); _send(); } catch (_) {} },
          child: const Text('保存并发送', style: TextStyle(color: _accent)))])); }
  @override
  Widget build(BuildContext c) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.mail_outline_rounded, size: 40, color: Color(0xFFEC4899)), const SizedBox(height: 12),
    const Text('📧 对话邮件摘要', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
    const SizedBox(height: 4), const Text('发送最新对话摘要，查看历史记录', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _textSecondary)), const SizedBox(height: 20),
    ElevatedButton.icon(onPressed: _sending ? null : _send,
      icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, size: 18),
      label: Text(_sending ? '发送中...' : '发送最新的对话摘要'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_status, textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: _status.startsWith('✅') ? const Color(0xFF10B981) : _textSecondary))),
    const SizedBox(height: 24), const Divider(color: _border), const SizedBox(height: 8),
    Row(children: [const Text('发送记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)), const Spacer(),
      IconButton(icon: const Icon(Icons.refresh, size: 18, color: _textSecondary), onPressed: _load)]),
    if (_ll) const Center(child: CircularProgressIndicator(color: _accent))
    else if (_list.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('暂无发送记录', style: TextStyle(color: _textSecondary, fontSize: 13))))
    else ...List.generate(_list.length, (i) { final e = _list[i]; final t = e['conv_title'] as String? ?? ''; final r = e['recipient'] as String? ?? ''; final p = e['summary_preview'] as String? ?? ''; final s = e['sent_at'] as String? ?? '';
      return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _cardBg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)), const SizedBox(width: 6),
            Expanded(child: Text(t, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 4), Text(p, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4), Row(children: [Text(r, style: const TextStyle(color: _textSecondary, fontSize: 10)), const Spacer(),
            Text(s.length >= 16 ? s.substring(0, 16) : s, style: const TextStyle(color: _textSecondary, fontSize: 10))])]));
    }),
  ]));
}
