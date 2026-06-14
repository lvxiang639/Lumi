import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});
  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/countdown');
      _items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final brightness = Theme.of(context).brightness;
    final titleCtrl = TextEditingController();
    DateTime picked = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.card(brightness),
          title: Text('新建倒数日', style: TextStyle(color: AppColors.text(brightness))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, autofocus: true,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(hintText: '事件名称', hintStyle: TextStyle(color: AppColors.textSecondary(brightness)))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy-MM-dd').format(picked)),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: picked, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setD(() => picked = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text, 'target_date': picked.toIso8601String()}),
              child: const Text('添加', style: TextStyle(color: AppColors.accent))),
          ],
        ),
      ),
    );
    if (result != null && (result['title'] as String).isNotEmpty) {
      await _api.post('/api/countdown', body: result);
      _load();
    }
  }

  Future<void> _delete(String id) async {
    await _api.delete('/api/countdown/$id');
    _load();
  }

  int _daysLeft(String dateStr) {
    final target = DateTime.parse(dateStr);
    final now = DateTime.now();
    return DateTime(target.year, target.month, target.day)
        .difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary(brightness)), onPressed: () => Navigator.pop(context)),
        title: Text('倒数日', style: TextStyle(color: AppColors.text(brightness), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _items.isEmpty
              ? _emptyState(brightness)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final days = _daysLeft(item['target_date'] as String);
                    final label = days > 0 ? '还有 $days 天' : days == 0 ? '🎉 就是今天！' : '已过去 ${-days} 天';
                    final color = days <= 3 && days >= 0 ? Colors.red : AppColors.accent;
                    return Dismissible(
                      key: ValueKey(item['id']),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(item['id'] as String),
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.red)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.card(brightness), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(width: 48, height: 48,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text('${days.abs()}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['title'] as String? ?? '', style: TextStyle(color: AppColors.text(brightness), fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                          ])),
                          Text(DateFormat('MM/dd').format(DateTime.parse(item['target_date'] as String)),
                              style: TextStyle(color: AppColors.textSecondary(brightness).withValues(alpha: 0.5), fontSize: 11)),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: _add, backgroundColor: AppColors.accent, child: const Icon(Icons.add, color: Colors.white)),
    );
  }

  Widget _emptyState(Brightness b) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.date_range, size: 32, color: AppColors.accent.withValues(alpha: 0.5))),
      const SizedBox(height: 16),
      Text('还没有倒数日', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('点击右下角按钮添加倒数日', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('新建倒数日')),
    ]),
  );
}
