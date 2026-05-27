import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (await hasPermission()) {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav));
    }
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    return path;
  }

  void dispose() => _recorder.dispose();
}
