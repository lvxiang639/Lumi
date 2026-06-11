import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';

class AgentRunPage extends StatefulWidget {
  final String agentId;
  const AgentRunPage({super.key, required this.agentId});
  @override
  State<AgentRunPage> createState() => _AgentRunPageState();
}

class _AgentRunPageState extends State<AgentRunPage> {
  Map<String, dynamic>? _agent;
  Map<String, dynamic>? _currentStep;
  Map<String, String> _answers = {};
  String? _result;
  bool _loading = true;
  final _textCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _loadAgent(); }

  Future<void> _loadAgent() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}'), headers: {'Authorization': 'Bearer $tok'});
    if (r.statusCode == 200) {
      _agent = json.decode(r.body);
      _nextStep();
    }
    setState(() => _loading = false);
  }

  Future<void> _nextStep() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final r = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}/run'), headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'}, body: json.encode({'answers': _answers}));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      if (d['status'] == 'done') {
        _result = d['result']; _currentStep = null;
        // Save run history
        try {
          await http.post(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}/save-run'), headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'}, body: json.encode({'answers': _answers, 'result': _result}));
        } catch (_) {}
      } else {
        _currentStep = d;
      }
    }
    setState(() {});
  }

  void _answer(String text) {
    if (_currentStep == null) return;
    _answers[_currentStep!['step_id'] as String] = text;
    _nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final icon = _agent?['icon'] as String? ?? '🤖';
    final name = _agent?['name'] as String? ?? 'Agent';

    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary(b)), onPressed: () => Navigator.pop(context)),
        title: Text('$icon $name', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.accent)) : _result != null ? _resultView(b) : _stepView(b),
    );
  }

  Widget _stepView(Brightness b) {
    if (_currentStep == null) return const Center(child: Text('加载中...'));
    final q = _currentStep!['question'] as String;
    final type = _currentStep!['answer_type'] as String;
    final choices = (_currentStep!['choices'] as List?)?.cast<String>() ?? [];
    final total = _currentStep!['total_steps'] as int;
    final cur = _currentStep!['step_order'] as int;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LinearProgressIndicator(value: cur / total, color: AppColors.accent, backgroundColor: AppColors.accent.withValues(alpha: 0.1)),
        const SizedBox(height: 6),
        Text('步骤 $cur / $total', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
        const SizedBox(height: 24),
        Text('🤖 $q', style: TextStyle(color: AppColors.text(b), fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 20),
        if (type == 'choice' && choices.isNotEmpty) ...choices.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => _answer(c),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(c, style: const TextStyle(fontSize: 15)),
          )),
        )),
        if (type != 'choice') TextField(
          controller: _textCtrl, autofocus: true,
          style: TextStyle(color: AppColors.text(b), fontSize: 15),
          decoration: InputDecoration(hintText: '输入你的回答...', hintStyle: TextStyle(color: AppColors.textSecondary(b)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onSubmitted: (v) { if (v.isNotEmpty) _answer(v); },
        ),
        if (type != 'choice') const SizedBox(height: 12),
        if (type != 'choice') SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () { if (_textCtrl.text.isNotEmpty) _answer(_textCtrl.text); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('下一步', style: TextStyle(fontSize: 15, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _resultView(Brightness b) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✅ 生成结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
          child: SelectableText(_result ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _restart, child: const Text('重新开始'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () {
              // Copy + snackbar
              Clipboard.setData(ClipboardData(text: _result ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('复制结果', style: TextStyle(color: Colors.white)),
          )),
        ]),
      ])),
    );
  }

  void _restart() { setState(() { _answers.clear(); _result = null; _currentStep = null; }); _nextStep(); }
}
