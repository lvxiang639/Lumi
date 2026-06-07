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

  Future<String?> downloadAndOpen(String fileId, String fileName) async {
    try {
      final token = (await SharedPreferences.getInstance())
              .getString('access_token') ?? '';
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/tools/files/$fileId/download');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        return '下载失败 (状态码: ${resp.statusCode})';
      }

      // Save to Downloads folder for persistent access
      final dir = Platform.isMacOS
          ? Directory('${Platform.environment['HOME']}/Downloads')
          : await getTemporaryDirectory();

      // Ensure unique filename
      String safeName = fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(resp.bodyBytes);

      // Verify file was written
      if (!await file.exists() || await file.length() == 0) {
        return '文件写入失败';
      }

      // Open with system default app
      final result = await Process.run(
        Platform.isMacOS ? 'open' : 'xdg-open',
        [file.path],
      );

      if (result.exitCode == 0) {
        return null; // success — null means no error
      }
      return '已保存到: ${file.path}';
    } catch (e) {
      return '打开失败: $e';
    }
  }

  void dispose() => _api.dispose();
}
