import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/ws_service.dart';

class ChatProvider extends ChangeNotifier {
  final WsService _ws = WsService();
  final List<Message> _messages = [];
  String _streamingText = "";
  bool _isProcessing = false;
  String? currentSkill;

  List<Message> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  bool get isProcessing => _isProcessing;

  void startConversation({String? conversationId}) {
    _messages.clear();
    _streamingText = "";
    _ws.conversationId = conversationId;
    _ws.messages.listen(_onWsMessage);
    _ws.connect();
  }

  void sendText(String text) {
    _messages.add(Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      type: 'text',
      content: text,
      createdAt: DateTime.now(),
    ));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendText(text);
  }

  void _onWsMessage(WsMessage msg) {
    switch (msg.type) {
      case 'asr_result':
        final text = msg.data['text'] as String;
        _messages.add(Message(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user',
          type: 'text',
          content: text,
          createdAt: DateTime.now(),
        ));
        break;
      case 'llm_stream':
        _streamingText += msg.data['delta'] as String;
        break;
      case 'skill_call':
        currentSkill = msg.data['skill'] as String?;
        break;
      case 'tts_audio':
        break;
      case 'done':
        if (_streamingText.isNotEmpty) {
          _messages.add(Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            type: 'text',
            content: _streamingText,
            createdAt: DateTime.now(),
          ));
          _streamingText = "";
        }
        _isProcessing = false;
        currentSkill = null;
        if (msg.data['conversation_id'] != null) {
          _ws.conversationId = msg.data['conversation_id'] as String;
        }
        break;
    }
    notifyListeners();
  }

  Future<void> endConversation() async {
    await _ws.disconnect();
    _messages.clear();
    _streamingText = "";
    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }
}
