import 'package:flutter/material.dart';
import '../services/notes_service.dart';
import '../theme/app_colors.dart';

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
    await _service.createMood(
        {'emotion': _selectedEmotion, 'intensity': 0.5, 'note': _moodNote});
    _moodNote = '';
    _load();
  }

  String _emojiFor(String emotion) {
    return _emotions.firstWhere((e) => e['name'] == emotion,
        orElse: () => _emotions[3])['emoji'] as String;
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
        title: Text('心情记录',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(brightness),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _emotions.map((e) {
                  final selected = _selectedEmotion == e['name'];
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedEmotion = e['name'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? (e['color'] as Color)
                                .withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(e['emoji'] as String,
                          style: TextStyle(
                              fontSize: selected ? 30 : 24)),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _moodNote = v,
                  style: TextStyle(
                      color: AppColors.text(brightness),
                      fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '记录一下心情...',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary(
                            brightness)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addMood,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Text('记录',
                      style: TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent))
              : _moods.isEmpty
                  ? Center(
                      child: Text('还没有心情记录',
                          style: TextStyle(
                              color: AppColors.textSecondary(
                                  brightness))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          16, 4, 16, 24),
                      itemCount: _moods.length,
                      itemBuilder: (ctx, i) {
                        final m = _moods[i];
                        final emotion =
                            m['emotion'] as String? ?? 'calm';
                        return Container(
                          margin:
                              const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.card(brightness),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Text(_emojiFor(emotion),
                                style: const TextStyle(
                                    fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  m['note'] as String? ??
                                      emotion,
                                  style: TextStyle(
                                      color: AppColors
                                          .textSecondary(
                                              brightness),
                                      fontSize: 12)),
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
