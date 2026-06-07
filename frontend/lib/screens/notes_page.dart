import 'package:flutter/material.dart';
import '../services/notes_service.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
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

  Future<void> _add() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('新建笔记', style: TextStyle(color: _textMain)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(labelText: '标题', labelStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
          const SizedBox(height: 8),
          TextField(controller: contentCtrl, maxLines: 3,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(labelText: '内容', labelStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text, 'content': contentCtrl.text, 'note_type': 'note'}),
            child: const Text('保存', style: TextStyle(color: _accent))),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('笔记', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _notes.isEmpty
              ? Center(child: Text('还没有笔记', style: TextStyle(color: _textDim)))
              : RefreshIndicator(
                  color: _accent, backgroundColor: _surface,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _notes.length,
                    itemBuilder: (ctx, i) {
                      final n = _notes[i];
                      return Dismissible(
                        key: ValueKey(n['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.red)),
                        onDismissed: (_) => _delete(n['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['title'] as String? ?? '', style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.w500)),
                            if ((n['content'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(n['content'] as String, style: TextStyle(color: _textDim, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add, backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}