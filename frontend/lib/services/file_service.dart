import 'api_client.dart';

class FileService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> listFiles() async {
    final data = await _api.get('/api/tools/files');
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  void dispose() => _api.dispose();
}