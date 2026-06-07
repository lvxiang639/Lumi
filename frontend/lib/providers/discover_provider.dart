import 'package:flutter/foundation.dart';

class DiscoverItem {
  final String id;
  final String text;
  final String? skill;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // structured data (e.g. news items)

  DiscoverItem({
    required this.id,
    required this.text,
    this.skill,
    required this.createdAt,
    this.data,
  });

  /// Decode news items from data field
  List<Map<String, dynamic>> get newsItems {
    if (skill != 'news' || data == null) return [];
    final raw = data!['items'] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }
}

class DiscoverProvider extends ChangeNotifier {
  static DiscoverProvider? _instance;
  static DiscoverProvider? get instance => _instance;

  final List<DiscoverItem> _items = [];
  int _unreadCount = 0;

  DiscoverProvider() {
    _instance = this;
  }

  List<DiscoverItem> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;

  static void add(String text, {String? skill, Map<String, dynamic>? data}) {
    _instance?.addItem(text, skill: skill, data: data);
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
    if (_items.length > 50) {
      _items.removeLast();
    }
    notifyListeners();
  }

  void markAllRead() {
    _unreadCount = 0;
    notifyListeners();
  }
}
