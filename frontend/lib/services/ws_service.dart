import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

enum WsState { disconnected, connecting, connected }

class WsMessage {
  final String type;
  final Map<String, dynamic> data;
  WsMessage(this.type, this.data);
}

class WsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  WsState _state = WsState.disconnected;
  final _controller = StreamController<WsMessage>.broadcast();
  String? conversationId;

  WsState get state => _state;
  Stream<WsMessage> get messages => _controller.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    _state = WsState.connecting;
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?token=$token'),
    );
    _state = WsState.connected;
    _subscription = _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _controller.add(WsMessage(json['type'] as String, json));
      },
      onDone: () {
        _state = WsState.disconnected;
      },
      onError: (_) {
        _state = WsState.disconnected;
      },
    );
  }

  void sendText(String text) {
    _channel?.sink.add(jsonEncode({
      'type': 'text',
      'content': text,
      'conversation_id': conversationId,
    }));
  }

  void sendVoice(String base64Audio) {
    _channel?.sink.add(jsonEncode({
      'type': 'voice',
      'audio': base64Audio,
      'conversation_id': conversationId,
    }));
  }

  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _state = WsState.disconnected;
    conversationId = null;
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
