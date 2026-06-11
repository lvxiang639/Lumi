import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'logger.dart';

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
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  static const _initialReconnectDelay = Duration(seconds: 1);
  void Function(WsState)? onStateChanged;

  WsState get state => _state;
  Stream<WsMessage> get messages => _controller.stream;

  Future<void> connect() async {
    await _doConnect();
  }

  void _setState(WsState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  Future<void> _doConnect() async {
    // Close any existing connection first
    _subscription?.cancel();
    _channel?.sink.close();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    _setState(WsState.connecting);
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?token=$token'),
      );
      _subscription = _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(WsMessage(json['type'] as String, json));
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
      await _channel!.ready;
      _setState(WsState.connected);
      _reconnectAttempts = 0;
      AppLogger.ws('已连接');
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    AppLogger.ws('已断开');
    _setState(WsState.disconnected);
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _initialReconnectDelay * pow(2, min(_reconnectAttempts, 5));
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    _reconnectAttempts++;

    AppLogger.ws('重连 ${delay + jitter} (第 $_reconnectAttempts 次)');
    _reconnectTimer = Timer(delay + jitter, _doConnect);
  }

  void sendText(String text) {
    _channel?.sink.add(jsonEncode({
      'type': 'text',
      'content': text,
      'conversation_id': conversationId,
    }));
  }

  // ============================================================
  // VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
  // ============================================================
  // void sendVoice(String base64Audio) {
  //   _channel?.sink.add(jsonEncode({
  //     'type': 'voice',
  //     'audio': base64Audio,
  //     'conversation_id': conversationId,
  //   }));
  // }
  // ============================================================

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(WsState.disconnected);
    conversationId = null;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
