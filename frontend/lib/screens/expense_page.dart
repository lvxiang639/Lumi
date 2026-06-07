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
          TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                  labelText: '金额',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(brightness)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(brightness))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.accent)))),
          TextField(
              controller: catCtrl,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                  labelText: '分类',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(brightness)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(brightness))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.accent)))),
          TextField(
              controller: rmkCtrl,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                  labelText: '备注',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(brightness)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(brightness))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.accent)))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color:
                          AppColors.textSecondary(brightness)))),
          TextButton(
              onPressed: () {
                final amt = double.tryParse(amtCtrl.text);
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx, {
                  'amount': amt,
                  'category': catCtrl.text,
                  'remark': rmkCtrl.text
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

  Future<void> _delete(String id) async {
    await _service.deleteExpense(id);
    _load();
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
              child:
                  CircularProgressIndicator(color: AppColors.accent))
          : _records.isEmpty
              ? Center(
                  child: Text('还没有记账记录',
                      style: TextStyle(
                          color: AppColors.textSecondary(
                              brightness))))
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.card(brightness),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      return Dismissible(
                        key: ValueKey(r.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete,
                                color: Colors.red)),
                        onDismissed: (_) => _delete(r.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card(brightness),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Text(r.category,
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13)),
                            const Spacer(),
                            Text(
                                '¥${r.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color:
                                        AppColors.text(brightness),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            if (r.remark.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(r.remark,
                                  style: TextStyle(
                                      color: AppColors.textSecondary(
                                          brightness),
                                      fontSize: 11)),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
