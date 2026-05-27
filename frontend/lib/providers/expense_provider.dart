import 'package:flutter/foundation.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  List<ExpenseRecord> _records = [];
  Map<String, dynamic>? _stats;
  bool _loading = false;

  List<ExpenseRecord> get records => List.unmodifiable(_records);
  Map<String, dynamic>? get stats => _stats;
  bool get loading => _loading;

  Future<void> load({String? category, String? month}) async {
    _loading = true;
    notifyListeners();
    try {
      _records = await _service.getExpenses(category: category, month: month);
      _stats = await _service.getStats();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> create(ExpenseRecord record) async {
    await _service.createExpense(record);
    await load();
  }

  Future<void> delete(String id) async {
    await _service.deleteExpense(id);
    await load();
  }
}
