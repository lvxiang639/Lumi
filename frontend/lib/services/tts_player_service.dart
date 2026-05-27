import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class TtsPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(Uint8List audioBytes) async {
    try {
      await _player.play(BytesSource(audioBytes));
    } catch (_) {}
  }

  Future<void> stop() async => _player.stop();
  void dispose() => _player.dispose();
}
