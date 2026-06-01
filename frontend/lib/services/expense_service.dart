import '../models/expense_record.dart';
import 'api_client.dart';

class ExpenseService {
  final ApiClient _api = ApiClient();

  Future<List<ExpenseRecord>> getExpenses(
      {String? category, String? month}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (month != null) params['month'] = month;
    final data = await _api.get('/api/expenses',
        queryParams: params.isNotEmpty ? params : null);
    final items = data['items'] as List? ?? [];
    return items
        .map((j) => ExpenseRecord.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseRecord> createExpense(ExpenseRecord record) async {
    final data = await _api.post('/api/expenses', body: record.toJson());
    return ExpenseRecord.fromJson(data);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('/api/expenses/$id');
  }

  Future<ExpenseRecord> updateExpense(String id, Map<String, dynamic> body) async {
    final data = await _api.put('/api/expenses/$id', body: body);
    return ExpenseRecord.fromJson(data);
  }

  Future<Map<String, dynamic>> getStats({String? period}) async {
    final params = <String, String>{};
    if (period != null) params['period'] = period;
    return await _api.get('/api/expenses/stats',
        queryParams: params.isNotEmpty ? params : null);
  }
}
