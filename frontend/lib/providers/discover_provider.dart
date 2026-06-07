import 'package:flutter/foundation.dart';

class DiscoverItem {
  final String id;
  final String text;
  final String? skill;
  final DateTime createdAt;

  DiscoverItem({
    required this.id,
    required this.text,
    this.skill,
    required this.createdAt,
  });
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

  static void add(String text, {String? skill}) {
    _instance?.addItem(text, skill: skill);
  }

  void addItem(String text, {String? skill}) {
    _items.insert(0, DiscoverItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      skill: skill,
      createdAt: DateTime.now(),
    ));
    _unreadCount++;
    // Keep max 50 items
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
