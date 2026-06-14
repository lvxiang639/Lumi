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
  List<TextEditingController> _fillCtls = [];  // one per blank

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
    for (final c in _fillCtls) { c.dispose(); }
    _fillCtls.clear();
  }

  void _initControllers() {
    _disposeControllers();
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final words = (q['words'] as List?) ?? [];
      for (int j = 0; j < words.length; j++) {
        _fillCtls.add(TextEditingController());
      }
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
    // Build answers in new format
    final answers = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final words = (q['words'] as List?) ?? [];
      final items = <Map<String, String>>[];
      for (int j = 0; j < words.length; j++) {
        final w = words[j] as Map<String, dynamic>;
        final filled = _fillCtls[_ctlIndex(i, j)].text.trim();
        if (filled.isNotEmpty) {
          items.add({'blank': w['blank'] as String? ?? '', 'filled': filled});
        }
      }
      if (items.isNotEmpty) {
        answers.add({'pinyin': q['pinyin'] ?? '', 'items': items});
      }
    }
    if (answers.isEmpty) {
      _snack('请至少填写一个空');
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

  int _ctlIndex(int groupIdx, int wordIdx) {
    int idx = 0;
    for (int i = 0; i < groupIdx; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      idx += ((q['words'] as List?) ?? []).length;
    }
    return idx + wordIdx;
  }

  Widget _practicingView(Brightness b) => Column(children: [
      LinearProgressIndicator(value: null, color: AppColors.accent, backgroundColor: AppColors.accent.withValues(alpha: 0.1)),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _questions.length,
          itemBuilder: (_, i) {
            final q = _questions[i] as Map<String, dynamic>;
            final pinyin = q['pinyin'] as String? ?? '';
            final words = (q['words'] as List?) ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(pinyin, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ),
                  const SizedBox(width: 10),
                  Text('第 ${i + 1} 组 · 同音字填空', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
                ]),
                const SizedBox(height: 14),
                ...List.generate(words.length, (j) {
                  final w = words[j] as Map<String, dynamic>;
                  final blank = w['blank'] as String? ?? '';
                  final hint = w['hint'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: b == Brightness.light ? const Color(0xFFF0F0F5) : const Color(0xFF1E2229),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(blank, textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.text(b), fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2)),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 48,
                        child: TextField(
                          controller: _fillCtls[_ctlIndex(i, j)],
                          style: TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '字',
                            hintStyle: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.4), fontSize: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(hint, style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.6), fontSize: 12))),
                    ]),
                  );
                }),
              ]),
            );
          },
        ),
      ),
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
          final pinyin = g['pinyin'] as String? ?? '';
          final results = (g['results'] as List?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(pinyin, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
                const SizedBox(width: 10),
                Text('第 ${i + 1} 组', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              ...results.map((r) {
                final item = r as Map<String, dynamic>;
                final correct = item['correct'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(correct ? Icons.check_circle : Icons.cancel, size: 16, color: correct ? Colors.green : Colors.red),
                    const SizedBox(width: 6),
                    Text(item['blank'] as String? ?? '',
                      style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text('→ ${item['filled'] ?? ''}',
                      style: TextStyle(color: correct ? Colors.green : Colors.red, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item['feedback'] as String? ?? '',
                      style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11))),
                  ]),
                );
              }),
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
        final completed = h['status'] == 'completed';
        return DraggableScrollableSheet(
          initialChildSize: 0.5, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
          builder: (ctx2, sc) => Container(
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                Expanded(child: Text('练习详情', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary(b))),
              ])),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('得分: ${h['score'] ?? '未完成'}  ·  ${_fmtTime(h['created_at'])}',
                  style: TextStyle(color: completed ? AppColors.accent : AppColors.textSecondary(b), fontSize: 12))),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (questions.isEmpty)
                    Text('暂无题目数据', style: TextStyle(color: AppColors.textSecondary(b)))
                  else
                    ...questions.map((q) {
                      final m = q as Map<String, dynamic>;
                      final pinyin = m['pinyin'] as String? ?? '';
                      final words = (m['words'] as List?) ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: b == Brightness.light ? const Color(0xFFF8F9FA) : const Color(0xFF1A1D21), borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(pinyin, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6366F1), fontSize: 14))),
                            const SizedBox(width: 8),
                            Text('${words.length} 个词语', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
                          ]),
                          const SizedBox(height: 8),
                          ...words.map((w) {
                            final wm = w as Map<String, dynamic>;
                            final blank = wm['blank'] as String? ?? '';
                            final answer = wm['answer'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(children: [
                                Text(blank, style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                if (answer.isNotEmpty)
                                  Text('→ $answer', style: TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700)),
                              ]),
                            );
                          }),
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
