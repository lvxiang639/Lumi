import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';

class AgentEditPage extends StatefulWidget {
  final String? agentId;
  const AgentEditPage({super.key, this.agentId});
  @override
  State<AgentEditPage> createState() => _AgentEditPageState();
}

class _AgentEditPageState extends State<AgentEditPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  String _icon = '🤖';
  List<Map<String, dynamic>> _steps = [];
  bool _loading = false;

  bool get _isEdit => widget.agentId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}'), headers: {'Authorization': 'Bearer $tok'});
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      _nameCtrl.text = d['name'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _promptCtrl.text = d['system_prompt'] ?? '';
      _icon = d['icon'] ?? '🤖';
      _steps = (d['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final body = {
      'name': _nameCtrl.text, 'description': _descCtrl.text,
      'icon': _icon, 'system_prompt': _promptCtrl.text,
      'steps': _steps,
    };
    final url = '${AppConfig.apiBaseUrl}/api/agents${_isEdit ? "/${widget.agentId}" : ""}';
    await (_isEdit
        ? http.put(Uri.parse(url), headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'}, body: json.encode(body))
        : http.post(Uri.parse(url), headers: {'Authorization': 'Bearer $tok', 'Content-Type': 'application/json'}, body: json.encode(body)));
    if (mounted) { Navigator.pop(context, true); }
  }

  void _addStep() {
    setState(() => _steps.add({'question': '', 'answer_type': 'text', 'choices': ''}));
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); _promptCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(title: Text(_isEdit ? '编辑 Agent' : '创建 Agent')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _field('名称', _nameCtrl),
        _field('描述', _descCtrl),
        _field('图标(emoji)', TextEditingController(text: _icon), onChanged: (v) => _icon = v),
        const SizedBox(height: 8),
        Text('系统提示词', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
        const SizedBox(height: 4),
        TextField(controller: _promptCtrl, maxLines: 3, style: TextStyle(color: AppColors.text(b), fontSize: 13), decoration: InputDecoration(hintText: '最终生成结果时发给 AI 的指令...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 16),
        Row(children: [Text('步骤 (${_steps.length})', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(onPressed: _addStep, icon: const Icon(Icons.add, size: 16), label: const Text('添加步骤'))]),
        ...List.generate(_steps.length, (i) {
          final s = _steps[i];
          return Card(
            child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
              Row(children: [
                Text('步骤 ${i + 1}', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(onTap: () => setState(() => _steps.removeAt(i)), child: const Icon(Icons.close, size: 16, color: Colors.red)),
              ]),
              TextField(controller: TextEditingController(text: s['question'] as String? ?? ''), onChanged: (v) => _steps[i]['question'] = v, style: TextStyle(color: AppColors.text(b), fontSize: 13), decoration: const InputDecoration(hintText: '问题', border: UnderlineInputBorder())),
              const SizedBox(height: 4),
              Row(children: [
                DropdownButton<String>(
                  value: s['answer_type'] as String? ?? 'text',
                  items: const [DropdownMenuItem(value: 'text', child: Text('文本')), DropdownMenuItem(value: 'number', child: Text('数字')), DropdownMenuItem(value: 'choice', child: Text('选项'))],
                  onChanged: (v) => setState(() => _steps[i]['answer_type'] = v ?? 'text'),
                  underline: const SizedBox(),
                ),
                if (s['answer_type'] == 'choice') ...[
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: TextEditingController(text: s['choices'] as String? ?? ''), onChanged: (v) => _steps[i]['choices'] = v, style: TextStyle(color: AppColors.text(b), fontSize: 12), decoration: const InputDecoration(hintText: '选项,逗号分隔', border: UnderlineInputBorder()))),
                ],
              ]),
            ])),
          );
        }),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.all(14)), child: Text(_loading ? '保存中...' : '保存 Agent', style: const TextStyle(fontSize: 15, color: Colors.white)))),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary(Theme.of(context).brightness), fontSize: 12)),
      TextField(controller: ctrl, onChanged: onChanged, style: TextStyle(color: AppColors.text(Theme.of(context).brightness), fontSize: 14), decoration: InputDecoration(border: const UnderlineInputBorder())),
    ]);
  }
}
