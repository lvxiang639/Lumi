import 'package:flutter/material.dart';
import '../services/expense_service.dart';
import '../models/expense_record.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

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
    final amtCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: '餐饮');
    final rmkCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('记一笔', style: TextStyle(color: _textMain)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amtCtrl, keyboardType: TextInputType.number,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(labelText: '金额', labelStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
          TextField(controller: catCtrl,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(labelText: '分类', labelStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
          TextField(controller: rmkCtrl,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(labelText: '备注', labelStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textDim))),
          TextButton(onPressed: () {
            final amt = double.tryParse(amtCtrl.text);
            if (amt == null || amt <= 0) return;
            Navigator.pop(ctx, {'amount': amt, 'category': catCtrl.text, 'remark': rmkCtrl.text});
          }, child: const Text('保存', style: TextStyle(color: _accent))),
        ],
      ),
    );
    if (result != null) {
      await _service.createExpense(ExpenseRecord(
        id: '', amount: result['amount'], category: result['category'],
        remark: result['remark'], recordedAt: DateTime.now(), createdAt: DateTime.now(),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('记账', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _records.isEmpty
              ? Center(child: Text('还没有记账记录', style: TextStyle(color: _textDim)))
              : RefreshIndicator(
                  color: _accent, backgroundColor: _surface,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      return Dismissible(
                        key: ValueKey(r.id),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.red)),
                        onDismissed: (_) => _delete(r.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                          child: Row(children: [
                            Text(r.category, style: const TextStyle(color: _accent, fontSize: 13)),
                            const Spacer(),
                            Text('¥${r.amount.toStringAsFixed(2)}', style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w600)),
                            if (r.remark.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(r.remark, style: TextStyle(color: _textDim, fontSize: 11)),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add, backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}