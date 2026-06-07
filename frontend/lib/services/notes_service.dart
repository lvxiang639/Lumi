import 'api_client.dart';

class NotesService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> listNotes({String? noteType}) async {
    final query = <String, String>{};
    if (noteType != null) query['note_type'] = noteType;
    final data = await _api.get('/api/notes', queryParams: query);
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, dynamic>> createNote(Map<String, dynamic> body) async {
    return await _api.post('/api/notes', body: body);
  }

  Future<void> updateNote(String id, Map<String, dynamic> body) async {
    await _api.put('/api/notes/$id', body: body);
  }

  Future<void> deleteNote(String id) async {
    await _api.delete('/api/notes/$id');
  }

  Future<List<Map<String, dynamic>>> listMoods() async {
    final data = await _api.get('/api/notes/moods');
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, dynamic>> createMood(Map<String, dynamic> body) async {
    return await _api.post('/api/notes/moods', body: body);
  }

  Future<Map<String, dynamic>> getMoodStats({String? period}) async {
    final query = <String, String>{};
    if (period != null) query['period'] = period;
    return await _api.get('/api/notes/moods/stats', queryParams: query);
  }

  void dispose() => _api.dispose();
}