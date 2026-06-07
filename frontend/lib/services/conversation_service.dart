import '../models/conversation.dart';
import 'api_client.dart';

class ConversationService {
  final ApiClient _api = ApiClient();

  Future<List<Conversation>> listConversations({int page = 1, int pageSize = 50}) async {
    final data = await _api.get('/api/conversations', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
    final items = data['items'] as List<dynamic>;
    return items.map((j) => Conversation.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> deleteConversation(String id) async {
    await _api.delete('/api/conversations/$id');
  }

  Future<void> renameConversation(String id, String title) async {
    await _api.put('/api/conversations/$id/title', body: {'title': title});
  }

  Future<String> getConversationMemory(String id) async {
    final data = await _api.get('/api/conversations/$id/memory');
    return data['summary_text'] as String? ?? '';
  }

  Future<String> summarizeConversation(String id) async {
    final data = await _api.post('/api/conversations/$id/summary');
    return data['summary'] as String? ?? '';
  }

  Future<List<Map<String, dynamic>>> listSummaries() async {
    final data = await _api.get('/api/conversations/summaries-all');
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  void dispose() {
    _api.dispose();
  }
}