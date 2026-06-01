import 'package:flutter/foundation.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  List<ExpenseRecord> _records = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _weeklyStats;
  bool _loading = false;
  String? _error;

  List<ExpenseRecord> get records => List.unmodifiable(_records);
  Map<String, dynamic>? get stats => _stats;
  Map<String, dynamic>? get weeklyStats => _weeklyStats;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({String? category, String? month}) async {
    _loading = true;
    notifyListeners();
    _error = null;
    try {
      _records = await _service.getExpenses(category: category, month: month);
      _stats = await _service.getStats();
      _weeklyStats = await _service.getStats(period: 'week');
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> create(ExpenseRecord record) async {
    await _service.createExpense(record);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _service.updateExpense(id, body);
    await load();
  }

  Future<void> delete(String id) async {
    await _service.deleteExpense(id);
    await load();
  }
}
