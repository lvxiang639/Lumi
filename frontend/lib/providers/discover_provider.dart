import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoverItem {
  final String id;
  final String text;
  final String? skill;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  DiscoverItem({
    required this.id,
    required this.text,
    this.skill,
    required this.createdAt,
    this.data,
  });

  List<Map<String, dynamic>> get newsItems {
    if (skill != 'news' || data == null) return [];
    final raw = data!['items'] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'skill': skill,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
  };

  factory DiscoverItem.fromJson(Map<String, dynamic> json) => DiscoverItem(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    skill: json['skill'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    data: json['data'] as Map<String, dynamic>?,
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
        _items.addAll(list.map((e) => DiscoverItem.fromJson(e as Map<String, dynamic>)));
        _unreadCount = prefs.getInt('discover_unread') ?? 0;
        notifyListeners();
      }
    } catch (_) {}
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

  void markAllRead() {
    _unreadCount = 0;
    _save();
    notifyListeners();
  }
}
