import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class WidgetService {
  /// Update iOS widget data — called on app start and periodically.
  static Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;

      final headers = {'Authorization': 'Bearer $token'};
      final base = AppConfig.apiBaseUrl;

      // Fetch weather (city-based)
      String weather = '--';
      try {
        final wResp = await http.get(Uri.parse('$base/api/expenses/insights/weekly'), headers: headers);
        if (wResp.statusCode == 200) {
          final data = json.decode(wResp.body);
          weather = data['current_emotion'] ?? '--';
        }
      } catch (_) {}

      // Fetch countdowns
      String countdown = '';
      try {
        final cResp = await http.get(Uri.parse('$base/api/countdown'), headers: headers);
        if (cResp.statusCode == 200) {
          final items = (json.decode(cResp.body)['items'] as List?) ?? [];
          if (items.isNotEmpty) {
            final first = items[0];
            final target = DateTime.parse(first['target_date'] as String);
            final days = target.difference(DateTime.now()).inDays;
            countdown = '${first['title']}: ${days > 0 ? "$days天" : days == 0 ? "今天" : "${-days}天前"}';
          }
        }
      } catch (_) {
        countdown = '';
      }

      // Write to SharedPreferences (App Group accessible by Widget)
      await prefs.setString('widget_weather', weather);
      await prefs.setString('widget_countdown', countdown);
      await prefs.setString('widget_updated', DateTime.now().toIso8601String());
    } catch (_) {}
  }
}
