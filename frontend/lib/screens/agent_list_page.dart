import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../theme/app_colors.dart';
import 'agent_run_page.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});
  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = (await SharedPreferences.getInstance()).getString('access_token') ?? '';
      final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/agents'), headers: {'Authorization': 'Bearer $tok'});
      if (r.statusCode == 200) _items = (json.decode(r.body)['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
      appBar: AppBar(title: Text('🤖 Agent', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.accent)) : _items.isEmpty ? _empty(b) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(item['icon'] as String? ?? '🤖', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item['description'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
              ])),
              IconButton(icon: Icon(Icons.play_arrow, color: AppColors.accent, size: 22), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentRunPage(agentId: item['id'] as String))).then((_) => _load())),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _delete(item['id'] as String)),
            ]),
          );
        },
      ),
    );
  }

  Widget _empty(Brightness b) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🤖', style: TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    Text('还没有 Agent', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 15)),
    const SizedBox(height: 4),
    Text('Agent 是自定义的多步骤 AI 工具', style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.6), fontSize: 12)),
  ]));
}
