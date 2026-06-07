import 'package:flutter/material.dart';
import '../services/notes_service.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

const _emotions = [
  {'emoji': '😊', 'name': 'joy', 'color': Color(0xFFF59E0B)},
  {'emoji': '😢', 'name': 'sad', 'color': Color(0xFF3B82F6)},
  {'emoji': '😡', 'name': 'angry', 'color': Color(0xFFEF4444)},
  {'emoji': '😌', 'name': 'calm', 'color': Color(0xFF10B981)},
  {'emoji': '😲', 'name': 'surprised', 'color': Color(0xFF8B5CF6)},
  {'emoji': '😰', 'name': 'worried', 'color': Color(0xFFEC4899)},
];

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});
  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  final NotesService _service = NotesService();
  List<Map<String, dynamic>> _moods = [];
  bool _loading = true;
  String _selectedEmotion = 'calm';
  String _moodNote = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _moods = await _service.listMoods();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addMood() async {
    await _service.createMood({'emotion': _selectedEmotion, 'intensity': 0.5, 'note': _moodNote});
    _moodNote = '';
    _load();
  }

  String _emojiFor(String emotion) {
    return _emotions.firstWhere((e) => e['name'] == emotion, orElse: () => _emotions[3])['emoji'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('心情记录', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: Column(children: [
        // Mood input area
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _emotions.map((e) {
              final selected = _selectedEmotion == e['name'];
              return GestureDetector(
                onTap: () => setState(() => _selectedEmotion = e['name'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? (e['color'] as Color).withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e['emoji'] as String, style: TextStyle(fontSize: selected ? 30 : 24)),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _moodNote = v,
                  style: const TextStyle(color: _textMain, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '记录一下心情...', hintStyle: TextStyle(color: _textDim),
                    border: InputBorder.none, contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addMood,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(16)),
                  child: const Text('记录', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ]),
          ]),
        ),
        // Mood history
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _moods.isEmpty
                  ? Center(child: Text('还没有心情记录', style: TextStyle(color: _textDim)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _moods.length,
                      itemBuilder: (ctx, i) {
                        final m = _moods[i];
                        final emotion = m['emotion'] as String? ?? 'calm';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                          child: Row(children: [
                            Text(_emojiFor(emotion), style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(m['note'] as String? ?? emotion, style: const TextStyle(color: _textDim, fontSize: 12)),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}