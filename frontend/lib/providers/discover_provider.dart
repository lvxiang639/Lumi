import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class DiscoverItem {
  final String id;
  final String text;
  final String? skill;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  List<String> comments;
  int likeCount;
  bool liked;

  DiscoverItem({
    required this.id,
    required this.text,
    this.skill,
    required this.createdAt,
    this.data,
    List<String>? comments,
    this.likeCount = 0,
    this.liked = false,
  }) : comments = comments ?? [];

  List<Map<String, dynamic>> get newsItems {
    if (skill != 'news' || data == null) return [];
    final raw = data!['items'] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'skill': skill,
    'createdAt': createdAt.toIso8601String(),
    'data': data, 'comments': comments, 'likeCount': likeCount, 'liked': liked,
  };

  factory DiscoverItem.fromJson(Map<String, dynamic> json) => DiscoverItem(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    skill: json['skill'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    data: json['data'] as Map<String, dynamic>?,
    comments: (json['comments'] as List?)?.cast<String>() ?? [],
    likeCount: json['likeCount'] as int? ?? 0,
    liked: json['liked'] == true,
  );
}

class DiscoverProvider extends ChangeNotifier {
  static DiscoverProvider? _instance;
  static DiscoverProvider? get instance => _instance;

  static const _storageKey = 'discover_items';
  final List<DiscoverItem> _items = [];
  int _unreadCount = 0;
  bool _loaded = false;

  DiscoverProvider() {
    _instance = this;
    _load();
  }

  List<DiscoverItem> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;

  static void add(String text, {String? skill, Map<String, dynamic>? data}) {
    _instance?.addItem(text, skill: skill, data: data);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = json.decode(raw) as List;
        final items = list.map((e) => DiscoverItem.fromJson(e as Map<String, dynamic>)).toList();
        // Clean up duplicates — key by skill + date for daily_content
        final seen = <String>{};
        items.removeWhere((item) {
          if (item.skill == 'daily_content') {
            final date = item.data?['_date'] as String? ?? item.createdAt.toIso8601String().substring(0, 10);
            final key = '${item.skill}_$date';
            if (seen.contains(key)) return true;
            seen.add(key);
          }
          return false;
        });
        _items.addAll(items);
        _unreadCount = prefs.getInt('discover_unread') ?? 0;
        notifyListeners();
      }
    } catch (_) {}
    // Fetch today's daily content from server
    _fetchDailyContent();
  }

  Future<void> _fetchDailyContent() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/discover/daily');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final content = data['content'];
        if (content != null && content is Map && content.isNotEmpty) {
          final todayKey = data['date'] as String? ?? '';
          final alreadyExists = _items.any((item) =>
            item.skill == 'daily_content' &&
            item.data?['_date'] == todayKey);
          if (!alreadyExists) {
            (content as Map<String, dynamic>)['_date'] = todayKey;
            _items.insert(0, DiscoverItem(
              id: 'daily_$todayKey',
              text: '📰 每日精选',
              skill: 'daily_content',
              data: content,
              createdAt: DateTime.now(),
            ));
            _unreadCount++;
            await _saveWithPrefs(prefs);
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveWithPrefs(SharedPreferences prefs) async {
    try {
      final list = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(list));
      await prefs.setInt('discover_unread', _unreadCount);
    } catch (_) {}
  }

  void refreshDailyContent() {
    _fetchDailyContent();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(list));
      await prefs.setInt('discover_unread', _unreadCount);
    } catch (_) {}
  }

  void addItem(String text, {String? skill, Map<String, dynamic>? data}) {
    // Dedup: skip duplicate daily_content (already received via HTTP or previous WS push)
    if (skill == 'daily_content') {
      final todayKey = DateTime.now().toIso8601String().substring(0, 10);
      final exists = _items.any((item) =>
        item.skill == 'daily_content' &&
        (item.id == 'daily_$todayKey' || item.data?['_date'] == todayKey));
      if (exists) return;
      // Set _date so future HTTP fetch can also dedup
      if (data != null) {
        data['_date'] = todayKey;
      }
    }
    _items.insert(0, DiscoverItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      skill: skill,
      data: data,
      createdAt: DateTime.now(),
    ));
    _unreadCount++;
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    _save();
    notifyListeners();
  }

  void toggleLike(String itemId) {
    for (final item in _items) {
      if (item.id == itemId) {
        if (item.liked) { item.likeCount--; item.liked = false; }
        else { item.likeCount++; item.liked = true; }
        break;
      }
    }
    _save(); notifyListeners();
  }

  void addComment(String itemId, String comment) {
    for (final item in _items) {
      if (item.id == itemId) { item.comments.add(comment); break; }
    }
    _save(); notifyListeners();
  }

  void markAllRead() {
    _unreadCount = 0;
    _save();
    notifyListeners();
  }
}
