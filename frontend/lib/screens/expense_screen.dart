import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final totalExpense = provider.stats?['total_expense'] ?? 0.0;
        return Scaffold(
          appBar: AppBar(
            title: const Text('记账'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('本月支出: ¥${totalExpense.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, color: Colors.indigo)),
              ),
            ),
          ),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : provider.records.isEmpty
                  ? const Center(child: Text('暂无记账记录', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: provider.records.length,
                      itemBuilder: (context, i) {
                        final record = provider.records[i];
                        final isExpense = record.amount > 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isExpense ? Colors.red.shade100 : Colors.green.shade100,
                            child: Text(record.category, style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(record.remark.isEmpty ? record.category : record.remark),
                          subtitle: Text(record.recordedAt.toString().substring(0, 16)),
                          trailing: Text(
                            '${isExpense ? "-" : "+"}¥${record.amount.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onLongPress: () => provider.delete(record.id),
                        );
                      },
                    ),
        );
      },
    );
  }
}
