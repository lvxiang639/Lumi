import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordStreamSub;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Stream<Uint8List>> start() async {
    if (await hasPermission()) {
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.wav),
      );
      return stream;
    }
    return const Stream.empty();
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    await _recordStreamSub?.cancel();
    _recordStreamSub = null;
    return path;
  }

  void dispose() {
    _recordStreamSub?.cancel();
    _recorder.dispose();
  }
}
