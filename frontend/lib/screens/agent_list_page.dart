import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../theme/app_colors.dart';
import 'agent_run_page.dart';
import 'agent_detail_page.dart';
import 'agent_edit_page.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});
  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> {
  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  int _tab = 0; // 0=Agent, 1=历史

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    final h = {'Authorization': 'Bearer $tok'};
    try {
      final ar = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents'), headers: h);
      if (ar.statusCode == 200) _agents = (json.decode(ar.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final hr = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/history'), headers: h);
      if (hr.statusCode == 200) _history = (json.decode(hr.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
    await http.delete(Uri.parse('${AppConfig.apiBaseUrl}/api/agents/$id'), headers: {'Authorization': 'Bearer $tok'});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(title: Text('🤖 Agent', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)), actions: [
        if (_tab == 0) IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentEditPage())).then((_) => _load())),
      ]),
      body: Column(children: [
        Row(children: [
          _tabBtn('Agent', 0), _tabBtn('历史记录', 1),
        ]),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.accent)) : _tab == 0 ? _agentList(b) : _historyList(b)),
      ]),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? AppColors.accent : AppColors.textSecondary(Theme.of(context).brightness), fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    ));
  }


  Widget _agentList(Brightness b) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _agents.length,
    itemBuilder: (_, i) {
      final a = _agents[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(a['icon'] as String? ?? '🤖', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(a['name'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w600)),
              if (a['is_public'] == true) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('系统', style: TextStyle(fontSize: 9, color: AppColors.accent)))],
            ]),
            const SizedBox(height: 2),
            Text(a['description'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
          ])),
          IconButton(icon: Icon(Icons.play_arrow, color: AppColors.accent, size: 22), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentDetailPage(agentId: a['id'] as String))).then((_) => _load())),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentEditPage(agentId: a['id'] as String))).then((_) => _load())),
          if (a['is_public'] != true) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16), onPressed: () => _delete(a['id'] as String)),
        ]),
      );
    },
  );

  Widget _historyList(Brightness b) => _history.isEmpty ? Center(child: Text('暂无使用记录', style: TextStyle(color: AppColors.textSecondary(b)))) : ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _history.length,
    itemBuilder: (_, i) {
      final h = _history[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.history, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(h['agent_name'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_fmtTime(h['created_at']), style: TextStyle(color: AppColors.textSecondary(b), fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text((h['result'] as String? ?? '').replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
        ]),
      );
    },
  );

  String _fmtTime(dynamic dt) {
    try { final d = DateTime.parse(dt as String); return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return ''; }
  }
}
