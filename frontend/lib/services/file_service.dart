import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'api_client.dart';

class FileService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> listFiles() async {
    final data = await _api.get('/api/tools/files');
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<bool> downloadAndOpen(String fileId, String fileName) async {
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('access_token') ?? '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/files/$fileId/download');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });
      if (resp.statusCode != 200) return false;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);

      // Open with system default app
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await Process.run('open', [file.path]);
      } else {
        // iOS/Android — file is saved, user can find it
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _api.dispose();
}
