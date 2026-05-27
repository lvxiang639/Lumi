import 'api_client.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> sync({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> expenses,
    required DateTime lastSyncAt,
  }) async {
    return await _api.post('/api/data/sync', body: {
      'events': events,
      'expenses': expenses,
      'last_sync_at': lastSyncAt.toIso8601String(),
    });
  }
}
