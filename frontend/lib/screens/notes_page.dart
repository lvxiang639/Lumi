import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notes_service.dart';
import '../theme/app_colors.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
  void _showNoteDetail(Map<String, dynamic> note, Brightness b) {

}

class _NotesPageState extends State<NotesPage> {
  final NotesService _service = NotesService();
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _notes = await _service.listNotes(noteType: 'note');
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showNoteDetail(Map<String, dynamic> note, Brightness b) {
    final title = note['title'] as String? ?? '';
    final content = note['content'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
              Expanded(child: Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: '$title

$content')); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1))); }, tooltip: '复制全部'),
            ])),
            const Divider(),
            Expanded(child: SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.all(20), child: SelectableText(content, style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.7)))),
          ]),
        ),
      ),
    );
  }

  Future<void> _add() async {
    final brightness = Theme.of(context).brightness;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(brightness),
        title: Text('新建笔记',
            style: TextStyle(color: AppColors.text(brightness))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                  labelText: '标题',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(brightness)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(brightness))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent)))),
          const SizedBox(height: 8),
          TextField(
              controller: contentCtrl,
              maxLines: 3,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                  labelText: '内容',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(brightness)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(brightness))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent)))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color: AppColors.textSecondary(brightness)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, {
                    'title': titleCtrl.text,
                    'content': contentCtrl.text,
                    'note_type': 'note'
                  }),
              child: const Text('保存',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (result != null && (result['title'] as String).isNotEmpty) {
      await _service.createNote(result);
      _load();
    }
  }

  Future<void> _delete(String id) async {
    await _service.deleteNote(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.textSecondary(brightness)),
            onPressed: () => Navigator.pop(context)),
        title: Text('笔记',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _notes.isEmpty
              ? Center(
                  child: Text('还没有笔记',
                      style: TextStyle(
                          color: AppColors.textSecondary(brightness))))
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card(brightness),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _notes.length,
                    itemBuilder: (ctx, i) {
                      final n = _notes[i];
                      return Dismissible(
                        key: ValueKey(n['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.red)),
                        onDismissed: (_) => _delete(n['id'] as String),
                        child: GestureDetector(
                          onTap: () => _showNoteDetail(n, brightness),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card(brightness),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['title'] as String? ?? '',
                                      style: TextStyle(
                                          color: AppColors.text(brightness),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  if ((n['content'] as String? ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(n['content'] as String,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                brightness),
                                            fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  void _showNoteDetail(Map<String, dynamic> note, Brightness b) {
    final title = note['title'] as String? ?? '';
    final content = note['content'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$title\n\n$content'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
                }, tooltip: '复制全部'),
              ]),
            ),
            const Divider(),
            Expanded(child: SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.all(20), child: SelectableText(content, style: TextStyle(color: AppColors.text(b), fontSize: 15, height: 1.7)))),
          ]),
        ),
      ),
    );
  }

}
