import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'logger.dart';

class ApiClient {
  final http.Client _client = http.Client();

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: queryParams);
    final resp = await _client.get(uri, headers: await _headers());
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.put(uri, headers: await _headers(), body: jsonEncode(body));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.delete(uri, headers: await _headers());
    return _handleResponse(resp);
  }

  void dispose() {
    _client.close();
  }

  Map<String, dynamic> _handleResponse(http.Response resp) {
    AppLogger.api('${resp.request?.method} ${resp.request?.url.path} → ${resp.statusCode}');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {'status': 'ok'};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    AppLogger.error('API ${resp.statusCode}: ${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');
    throw ApiException(resp.statusCode, resp.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
