import 'api_client.dart';

class EmailService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> sendEmailSummary(String convId) async {
    return await _api.post('/api/conversations/$convId/email-summary');
  }

  Future<List<Map<String, dynamic>>> listSentEmails() async {
    final data = await _api.get('/api/conversations/sent-emails');
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  void dispose() => _api.dispose();
}