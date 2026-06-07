import 'package:flutter/material.dart';
import '../services/expense_service.dart';
import '../models/expense_record.dart';
import '../theme/app_colors.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final ExpenseService _service = ExpenseService();
  List<ExpenseRecord> _records = [];
  Map<String, dynamic>? _stats;
  String _period = 'month';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _records = await _service.getExpenses();
      _stats = await _service.getStats(period: _period);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final brightness = Theme.of(context).brightness;
    final amtCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: '餐饮');
    final rmkCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(brightness),
        title: Text('记一笔',
            style: TextStyle(color: AppColors.text(brightness))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(amtCtrl, '金额', TextInputType.number,
              '¥', brightness),
          _dialogField(catCtrl, '分类', TextInputType.text, '',
              brightness),
          _dialogField(rmkCtrl, '备注', TextInputType.text, '',
              brightness),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color: AppColors.textSecondary(brightness)))),
          TextButton(
              onPressed: () {
                final amt = double.tryParse(amtCtrl.text);
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx, {
                  'amount': amt,
                  'category': catCtrl.text,
                  'remark': rmkCtrl.text,
                });
              },
              child: const Text('保存',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (result != null) {
      await _service.createExpense(ExpenseRecord(
        id: '',
        amount: result['amount'],
        category: result['category'],
        remark: result['remark'],
        recordedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      _load();
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label,
      TextInputType kb, String prefix, Brightness b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: kb,
        style: TextStyle(color: AppColors.text(b)),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix.isNotEmpty ? prefix : null,
          labelStyle:
              TextStyle(color: AppColors.textSecondary(b)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border(b))),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent)),
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    await _service.deleteExpense(id);
    _load();
  }

  String _fmtTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 18,
                color: AppColors.textSecondary(brightness)),
            onPressed: () => Navigator.pop(context)),
        title: Text('记账',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card(brightness),
              onRefresh: _load,
              child: _records.isEmpty
                  ? _emptyState(brightness)
                  : _body(brightness),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _body(Brightness b) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        _statsCard(b),
        const SizedBox(height: 16),
        _periodToggle(b),
        const SizedBox(height: 12),
        _categoryChart(b),
        const SizedBox(height: 16),
        Text('明细',
            style: TextStyle(
                color: AppColors.text(b),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._records.map((r) => _recordCard(r, b)),
      ],
    );
  }

  // ── Stats Card ──

  Widget _statsCard(Brightness b) {
    final total = (_stats?['total_expense'] as num?)?.toDouble() ?? 0;
    final catMap = _stats?['by_category'] as Map<String, dynamic>? ?? {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withValues(alpha: 0.08),
                   AppColors.accent.withValues(alpha: 0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_period == "week" ? "本周" : "本月"}支出',
                  style: TextStyle(
                      color: AppColors.textSecondary(b),
                      fontSize: 12)),
              const SizedBox(height: 4),
              Text('¥${total.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: AppColors.text(b),
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${catMap.length} 个分类',
                style: TextStyle(
                    color: AppColors.textSecondary(b),
                    fontSize: 11)),
            const SizedBox(height: 2),
            Text('${_records.length} 笔记录',
                style: TextStyle(
                    color: AppColors.textSecondary(b),
                    fontSize: 11)),
          ],
        ),
      ]),
    );
  }

  // ── Period Toggle ──

  Widget _periodToggle(Brightness b) {
    return Row(children: [
      _periodChip('week', '本周', b),
      const SizedBox(width: 8),
      _periodChip('month', '本月', b),
    ]);
  }

  Widget _periodChip(String value, String label, Brightness b) {
    final active = _period == value;
    return GestureDetector(
      onTap: () {
        setState(() => _period = value);
        _loadStats();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Future<void> _loadStats() async {
    try {
      _stats = await _service.getStats(period: _period);
      setState(() {});
    } catch (_) {}
  }

  // ── Category Bar Chart ──

  Widget _categoryChart(Brightness b) {
    final catMap = _stats?['by_category'] as Map<String, dynamic>? ?? {};
    if (catMap.isEmpty) return const SizedBox.shrink();

    final entries = catMap.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final maxVal = (entries.first.value as num).toDouble();
    if (maxVal == 0) return const SizedBox.shrink();

    final catColors = {
      '餐饮': const Color(0xFFF97316), '交通': const Color(0xFF3B82F6),
      '购物': const Color(0xFFEC4899), '娱乐': const Color(0xFF8B5CF6),
      '住房': const Color(0xFF10B981), '医疗': const Color(0xFFEF4444),
      '教育': const Color(0xFF6366F1),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('分类统计',
              style: TextStyle(
                  color: AppColors.textSecondary(b),
                  fontSize: 12)),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final val = (e.value as num).toDouble();
            final pct = val / maxVal;
            final color =
                catColors[e.key] ?? AppColors.accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                    width: 40,
                    child: Text(e.key,
                        style: TextStyle(
                            color: AppColors.text(b),
                            fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 16,
                      backgroundColor:
                          color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 60,
                    child: Text('¥${val.toStringAsFixed(0)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: AppColors.textSecondary(b),
                            fontSize: 11,
                            fontWeight: FontWeight.w500))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Record Card ──

  Widget _recordCard(ExpenseRecord r, Brightness b) {
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.red)),
      onDismissed: (_) => _delete(r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(b),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 6, height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category,
                    style: TextStyle(
                        color: AppColors.text(b),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Row(children: [
                  Text(_fmtTime(r.recordedAt),
                      style: TextStyle(
                          color: AppColors.textSecondary(b)
                              .withValues(alpha: 0.6),
                          fontSize: 11)),
                  if (r.remark.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.remark,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondary(b)
                                  .withValues(alpha: 0.5),
                              fontSize: 11)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          Text('¥${r.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: AppColors.text(b),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _emptyState(Brightness b) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 56,
            color: AppColors.textSecondary(b)
                .withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('还没有记账记录',
            style: TextStyle(
                color: AppColors.textSecondary(b),
                fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('记一笔'),
        ),
      ]),
    );
  }
}
