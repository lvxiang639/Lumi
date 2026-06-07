import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

      // Save to persistent location
      final dir = Platform.isMacOS
          ? Directory('${Platform.environment['HOME']}/Downloads')
          : await getApplicationDocumentsDirectory();

      String safeName = fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(resp.bodyBytes);

      if (!await file.exists() || await file.length() == 0) {
        return '文件写入失败';
      }

      // Open — url_launcher works on all platforms
      final fileUri = Uri.file(file.path);
      final ok = await launchUrl(fileUri,
          mode: LaunchMode.externalApplication);
      return ok ? null : '已保存到: ${file.path}';
    } catch (e) {
      return '打开失败: $e';
    }
  }

  void dispose() => _api.dispose();
}
