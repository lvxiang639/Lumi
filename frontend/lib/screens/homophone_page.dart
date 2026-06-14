import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

enum _Mode { idle, practicing, reviewing }

class HomophonePage extends StatefulWidget {
  const HomophonePage({super.key});
  @override
  State<HomophonePage> createState() => _HomophonePageState();
}

class _HomophonePageState extends State<HomophonePage> {
  final ApiClient _api = ApiClient();

  _Mode _mode = _Mode.idle;
  bool _loading = false;

  // Current exercise
  String? _exerciseId;
  List<dynamic> _questions = [];
  List<List<TextEditingController>> _charCtls = [];
  List<List<TextEditingController>> _wordCtls = [];

  // Grading result
  List<dynamic>? _grading;
  String? _score;
  String? _summary;

  // History
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _disposeControllers();
    _api.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final row in _charCtls) {
      for (final c in row) { c.dispose(); }
    }
    for (final row in _wordCtls) {
      for (final c in row) { c.dispose(); }
    }
    _charCtls.clear();
    _wordCtls.clear();
  }

  void _initControllers() {
    _disposeControllers();
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final cnt = (q['expected_count'] as int?) ?? 3;
      final chars = <TextEditingController>[];
      final words = <TextEditingController>[];
      for (int j = 0; j < cnt + 1; j++) {
        // +1 extra row for flexibility
        chars.add(TextEditingController());
        words.add(TextEditingController());
      }
      _charCtls.add(chars);
      _wordCtls.add(words);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.get('/api/study/homophone/history');
      _history = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final data = await _api.post('/api/study/homophone/generate');
      _exerciseId = data['id'] as String?;
      _questions = (data['questions'] as List?) ?? [];
      if (_questions.isEmpty) {
        _snack('生成失败，请重试');
        setState(() => _loading = false);
        return;
      }
      _initControllers();
      setState(() { _mode = _Mode.practicing; _loading = false; });
    } catch (e) {
      _snack('生成失败: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    // Build answers
    final answers = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final items = <Map<String, String>>[];
      for (int j = 0; j < _charCtls[i].length; j++) {
        final ch = _charCtls[i][j].text.trim();
        final wd = _wordCtls[i][j].text.trim();
        if (ch.isNotEmpty && wd.isNotEmpty) {
          items.add({'char': ch, 'word': wd});
        }
      }
      if (items.isNotEmpty) {
        answers.add({'target_char': q['target_char'] ?? '', 'items': items});
      }
    }
    if (answers.isEmpty) {
      _snack('请至少填写一组答案');
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await _api.post('/api/study/homophone/$_exerciseId/submit', body: {'answers': answers});
      _grading = (data['grading'] as List?) ?? [];
      _score = data['score'] as String?;
      _summary = data['summary'] as String?;
      _loadHistory();
      setState(() { _mode = _Mode.reviewing; _loading = false; });
    } catch (e) {
      _snack('提交失败: $e');
      setState(() => _loading = false);
    }
  }

  void _reset() {
    _disposeControllers();
    _exerciseId = null;
    _questions = [];
    _grading = null;
    _score = null;
    _summary = null;
    setState(() => _mode = _Mode.idle);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    switch (_mode) {
      case _Mode.idle: return _idleView(b);
      case _Mode.practicing: return _practicingView(b);
      case _Mode.reviewing: return _reviewingView(b);
    }
  }

  Widget _idleView(Brightness b) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Hero card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Text('📝', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('同音字组词闯关', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('每轮5道题，写出同音字并组词', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('开始闯关', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      // History
      if (_history.isNotEmpty) ...[
        Text('练习记录', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._history.take(10).map((h) => GestureDetector(
          onTap: () => _showHistoryDetail(h, b),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: (h['status'] == 'completed' ? AppColors.accent : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(h['status'] == 'completed' ? Icons.check_circle : Icons.pending, size: 18, color: h['status'] == 'completed' ? AppColors.accent : Colors.grey)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('同音字组词 · ${_fmtTime(h['created_at'])}', style: TextStyle(color: AppColors.text(b), fontSize: 13, fontWeight: FontWeight.w500)),
                if (h['score'] != null && (h['score'] as String).isNotEmpty)
                  Text('得分: ${h['score']}', style: TextStyle(color: AppColors.accent, fontSize: 11)),
              ])),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ]),
          ),
        )),
      ] else if (_history.isEmpty)
        Center(child: Text('还没有练习记录', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13))),
    ],
  );

  Widget _practicingView(Brightness b) => Column(children: [
    // Progress bar
    LinearProgressIndicator(value: null, color: AppColors.accent, backgroundColor: AppColors.accent.withValues(alpha: 0.1)),
    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (_, i) {
          final q = _questions[i] as Map<String, dynamic>;
          final target = q['target_char'] as String? ?? '';
          final pinyin = q['pinyin'] as String? ?? '';
          final hint = q['hint'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Question header
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(target, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('第 ${i + 1} 题', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
                  Text(hint, style: TextStyle(color: AppColors.text(b), fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('拼音: $pinyin', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 12),
              // Answer rows
              ...List.generate(_charCtls[i].length, (j) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _charCtls[i][j],
                        style: TextStyle(color: AppColors.text(b), fontSize: 16),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '字',
                          hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('—', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _wordCtls[i][j],
                        style: TextStyle(color: AppColors.text(b), fontSize: 16),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '组词',
                          hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ]),
          );
        },
      ),
    ),
    // Submit button
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('提交批改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  ]);

  Widget _reviewingView(Brightness b) => Column(children: [
    // Score banner
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _score != null && (_score!.startsWith('0/') || _score == '')
          ? Colors.red.shade50
          : AppColors.accent.withValues(alpha: 0.08),
      child: Column(children: [
        Text(_score ?? '', style: TextStyle(color: AppColors.accent, fontSize: 28, fontWeight: FontWeight.w700)),
        if (_summary != null) ...[
          const SizedBox(height: 4),
          Text(_summary!, style: TextStyle(color: AppColors.text(b), fontSize: 14), textAlign: TextAlign.center),
        ],
      ]),
    ),
    const SizedBox(height: 12),
    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _grading?.length ?? 0,
        itemBuilder: (_, i) {
          final g = _grading![i] as Map<String, dynamic>;
          final target = g['target_char'] as String? ?? '';
          final results = (g['results'] as List?) ?? [];
          final missing = (g['missing'] as List?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(target, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))))),
                const SizedBox(width: 10),
                Text('第 ${i + 1} 题', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              // Results
              ...results.map((r) {
                final item = r as Map<String, dynamic>;
                final correct = item['correct'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(correct ? Icons.check_circle : Icons.cancel, size: 16, color: correct ? Colors.green : Colors.red),
                    const SizedBox(width: 6),
                    Text('${item['char'] ?? ''} — ${item['word'] ?? ''}',
                      style: TextStyle(color: correct ? Colors.green : Colors.red, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item['feedback'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11))),
                  ]),
                );
              }),
              // Missing hints
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('💡 还可以写的同音字:', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...missing.map((m) {
                      final item = m as Map<String, dynamic>;
                      return Text('${item['char'] ?? ''} — ${item['word'] ?? ''}  ${item['hint'] ?? ''}',
                        style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12));
                    }),
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    ),
    // Action buttons
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('返回'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () { _reset(); _generate(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('再来一组', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
  ]);

  void _showHistoryDetail(Map<String, dynamic> h, Brightness b) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final questions = (h['questions'] as List?) ?? [];
        return DraggableScrollableSheet(
          initialChildSize: 0.5, maxChildSize: 0.8, minChildSize: 0.3, expand: false,
          builder: (ctx2, sc) => Container(
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                Expanded(child: Text('练习详情', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary(b))),
              ])),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('得分: ${h['score'] ?? '未完成'}  ·  ${_fmtTime(h['created_at'])}', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12))),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ...questions.map((q) {
                  final m = q as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Center(child: Text(m['target_char'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6366F1))))),
                      const SizedBox(width: 8),
                      Text('${m['hint'] ?? ''}  (${m['pinyin'] ?? ''})', style: TextStyle(color: AppColors.text(b), fontSize: 13)),
                    ]),
                  );
                }),
              ]))),
            ]),
          ),
        );
      },
    );
  }

  String _fmtTime(dynamic dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt as String);
      return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
