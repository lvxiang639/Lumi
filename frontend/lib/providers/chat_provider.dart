import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/ws_service.dart';
import '../services/api_client.dart';

class ChatProvider extends ChangeNotifier {
  final WsService _ws = WsService();
  final List<Message> _messages = [];
  StreamSubscription<WsMessage>? _wsSubscription;
  String _streamingText = "";
  bool _isProcessing = false;
  String? currentSkill;
  WsState _wsState = WsState.disconnected;
  String _emotion = 'calm';
  double _emotionIntensity = 0.0;
  String? _conversationId;
  bool _historyLoaded = false;

  List<Message> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  bool get isProcessing => _isProcessing;
  WsState get wsState => _wsState;
  String? get conversationId => _conversationId;
  String get emotion => _emotion;
  double get emotionIntensity => _emotionIntensity;
  bool get historyLoaded => _historyLoaded;

  void startConversation({String? conversationId}) {
    _wsSubscription?.cancel();
    _messages.clear();
    _streamingText = "";
    _conversationId = conversationId;
    _ws.conversationId = conversationId;
    _historyLoaded = false;

    // If reopening an existing conversation, load history via REST first
    if (conversationId != null) {
      loadHistory(conversationId);
    }

    _ws.onStateChanged = (s) {
      _wsState = s;
      notifyListeners();
    };
    _wsSubscription = _ws.messages.listen(_onWsMessage);
    _ws.connect();
  }

  Future<void> loadHistory(String convId) async {
    final api = ApiClient();
    try {
      final data = await api.get('/api/conversations/$convId/messages');
      final items = data['items'] as List<dynamic>;
      _messages.clear();
      _messages.addAll(
        items.map((j) => Message.fromJson(j as Map<String, dynamic>)).toList(),
      );
      _historyLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory failed: $e');
    } finally {
      api.dispose();
    }
  }

  void sendText(String text) {
    _messages.add(Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user', type: 'text', content: text,
      createdAt: DateTime.now(),
    ));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendText(text);
  }

  void _onWsMessage(WsMessage msg) {
    switch (msg.type) {
      case 'llm_stream':
        _streamingText += msg.data['delta'] as String;
        break;
      case 'skill_call':
        currentSkill = msg.data['skill'] as String?;
        _onSkillCall(msg.data);
        break;
      case 'emotion_update':
        _emotion = msg.data['emotion'] as String? ?? 'calm';
        _emotionIntensity = (msg.data['intensity'] as num?)?.toDouble() ?? 0.0;
        break;
      case 'done':
        if (_streamingText.isNotEmpty) {
          _messages.add(Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant', type: 'text', content: _streamingText,
            createdAt: DateTime.now(),
          ));
          _streamingText = "";
        }
        _isProcessing = false;
        currentSkill = null;
        if (msg.data['conversation_id'] != null) {
          _conversationId = msg.data['conversation_id'] as String;
          _ws.conversationId = _conversationId;
        }
        break;
    }
    notifyListeners();
  }

  void _onSkillCall(Map<String, dynamic> data) {
    // Skill calls are handled by the backend — frontend only displays them
  }

  Future<void> endConversation() async {
    await _ws.disconnect();
    _messages.clear();
    _streamingText = "";
    _isProcessing = false;
    _conversationId = null;
    _historyLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _ws.dispose();
    super.dispose();
  }
}