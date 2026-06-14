import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';
import 'agent_run_page.dart';
import 'agent_edit_page.dart';

class AgentDetailPage extends StatefulWidget {
  final String agentId;
  const AgentDetailPage({super.key, required this.agentId});
  @override
  State<AgentDetailPage> createState() => _AgentDetailPageState();
}

class _AgentDetailPageState extends State<AgentDetailPage> {
  Map<String, dynamic>? _agent;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final h = {'Authorization': 'Bearer $tok'};
    final ar = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}'), headers: h);
    if (ar.statusCode == 200) _agent = json.decode(ar.body);
    final hr = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/${widget.agentId}/history'), headers: h);
    if (hr.statusCode == 200) _history = (json.decode(hr.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    setState(() => _loading = false);
  }

  void _showHistoryDetail(Map<String, dynamic> h, Brightness b) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, maxChildSize: 0.8, minChildSize: 0.3, expand: false,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(color: AppColors.card(b), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: AppColors.border(b), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
              Expanded(child: Text(_agent?['name'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600))),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary(b))),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(_fmtTime(h['created_at']), style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12))),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(child: SingleChildScrollView(controller: sc, padding: const EdgeInsets.all(20), child: SelectableText(h['result'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, height: 1.6)))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (_loading) return Scaffold(backgroundColor: AppColors.bg(b), body: const Center(child: CircularProgressIndicator(color: AppColors.accent)));
    if (_agent == null) return Scaffold(backgroundColor: AppColors.bg(b), appBar: AppBar(), body: const Center(child: Text('未找到')));

    final icon = _agent!['icon'] as String? ?? '🤖';
    final name = _agent!['name'] as String? ?? '';
    final desc = _agent!['description'] as String? ?? '';
    final steps = (_agent!['steps'] as List?) ?? [];
    final prompt = _agent!['system_prompt'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(title: Text('$icon $name'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentEditPage(agentId: widget.agentId))).then((_) => _load())),
      ]),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          // Header
          Center(child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(color: AppColors.text(b), fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 14)),
          ])),
          const SizedBox(height: 24),
          // Steps preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('共 ${steps.length} 个步骤', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...steps.asMap().entries.map((e) {
                final s = e.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 22, height: 22, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)), child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s['question'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 16),
          // System prompt
          if (prompt.isNotEmpty) Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('提示词', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(prompt, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 24),
          // Start button
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentRunPage(agentId: widget.agentId))).then((_) => _load()),
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
          const SizedBox(height: 32),
          // History
          if (_history.isNotEmpty) ...[
            Text('使用记录', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._history.take(10).map((h) => GestureDetector(
              onTap: () => _showHistoryDetail(h, b),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.history, size: 12, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_fmtTime(h['created_at']), style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)),
                  ]),
                  const SizedBox(height: 4),
                  Text((h['result'] as String? ?? '').replaceAll('\n', ' '), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text(b), fontSize: 12, height: 1.4)),
                ]),
              ),
            )),
          ],
        ]),
      ),
    );
  }

  String _fmtTime(dynamic dt) {
    try { final d = DateTime.parse(dt as String); return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return ''; }
  }
}
