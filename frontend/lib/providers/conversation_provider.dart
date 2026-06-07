import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';

class ConversationProvider extends ChangeNotifier {
  final ConversationService _service = ConversationService();
  List<Conversation> _conversations = [];
  bool _loading = false;
  String? _error;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await _service.listConversations();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> rename(String id, String title) async {
    try {
      await _service.renameConversation(id, title);
      final idx = _conversations.indexWhere((c) => c.id == id);
      if (idx != -1) {
        final old = _conversations[idx];
        _conversations[idx] = Conversation(
          id: old.id,
          title: title,
          lastMessage: old.lastMessage,
          createdAt: old.createdAt,
          updatedAt: old.updatedAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _service.deleteConversation(id);
      _conversations.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void dispose() {
    _service.dispose();
    super.dispose();
  }
}