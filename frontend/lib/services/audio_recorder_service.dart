import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/lingxi_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _currentPath!,
    );
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    return path;
  }

  void dispose() {
    _currentPath = null;
    _recorder.dispose();
  }
}
