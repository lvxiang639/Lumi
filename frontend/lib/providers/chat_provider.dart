import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/ws_service.dart';
import '../services/tts_player_service.dart';

enum CharacterAnimState { idle, talking, dancing }

class ChatProvider extends ChangeNotifier {
  final WsService _ws = WsService();
  final TtsPlayerService _tts = TtsPlayerService();
  final List<Message> _messages = [];
  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<double>? _ttsProgressSub;
  String _streamingText = "";
  bool _isProcessing = false;
  String? currentSkill;
  WsState _wsState = WsState.disconnected;
  CharacterAnimState _animState = CharacterAnimState.idle;
  double _mouthOpen = 0.0;

  List<Message> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  bool get isProcessing => _isProcessing;
  WsState get wsState => _wsState;
  bool get isTtsPlaying => _tts.isPlaying;
  CharacterAnimState get animState => _animState;
  double get mouthOpen => _mouthOpen;

  void stopTts() => _tts.stop();

  void setAnimState(CharacterAnimState state) {
    _animState = state;
    notifyListeners();
  }

  void startConversation({String? conversationId}) {
    _tts.stop();
    _wsSubscription?.cancel();
    _ttsProgressSub?.cancel();
    _messages.clear();
    _streamingText = "";
    _ws.conversationId = conversationId;
    _ws.onStateChanged = (s) {
      _wsState = s;
      notifyListeners();
    };
    _tts.onPlaybackDone = () {
      _animState = CharacterAnimState.idle;
      _mouthOpen = 0.0;
      notifyListeners();
    };
    _ttsProgressSub = _tts.playbackProgress.listen((progress) {
      if (progress > 0 && progress < 1.0) {
        _animState = CharacterAnimState.talking;
        _mouthOpen = _mouthFromProgress(progress);
      } else {
        _mouthOpen = 0.0;
      }
      notifyListeners();
    });
    _wsSubscription = _ws.messages.listen(_onWsMessage);
    _ws.connect();
  }

  double _mouthFromProgress(double progress) {
    final t = progress * 10;
    final val = (t - t.floor()) < 0.4 ? 1.0 : 0.0;
    return val;
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

  void sendVoice(String base64Audio) {
    _messages.add(Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user', type: 'voice', content: '[语音消息]',
      createdAt: DateTime.now(),
    ));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendVoice(base64Audio);
  }

  void _onWsMessage(WsMessage msg) {
    switch (msg.type) {
      case 'asr_result':
        final text = msg.data['text'] as String;
        _messages.add(Message(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user', type: 'text', content: text,
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
        final audioBase64 = msg.data['audio'] as String?;
        if (audioBase64 != null) {
          final bytes = base64Decode(audioBase64);
          _tts.addChunk(Uint8List.fromList(bytes));
          _tts.finishStream();
        }
        break;
      case 'tts_audio_chunk':
        final chunkBase64 = msg.data['chunk'] as String?;
        if (chunkBase64 != null) {
          _tts.addChunk(Uint8List.fromList(base64Decode(chunkBase64)));
        }
        break;
      case 'tts_audio_end':
        _tts.finishStream();
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
        _animState = CharacterAnimState.idle;
        _mouthOpen = 0.0;
        currentSkill = null;
        if (msg.data['conversation_id'] != null) {
          _ws.conversationId = msg.data['conversation_id'] as String;
        }
        break;
    }
    notifyListeners();
  }

  Future<void> endConversation() async {
    _ttsProgressSub?.cancel();
    await _ws.disconnect();
    _messages.clear();
    _streamingText = "";
    _isProcessing = false;
    _animState = CharacterAnimState.idle;
    _mouthOpen = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _ttsProgressSub?.cancel();
    _tts.dispose();
    _ws.dispose();
    super.dispose();
  }
}
