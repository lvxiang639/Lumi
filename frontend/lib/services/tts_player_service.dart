// ============================================================
// VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
// ============================================================
// import 'dart:async';
// import 'dart:io';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';

// class TtsPlayerService {
//   final AudioPlayer _player = AudioPlayer();
//   bool _isPlaying = false;
//   VoidCallback? onPlaybackDone;
//   final List<Uint8List> _buffer = [];
//   StreamSubscription<Duration>? _posSub;
//   Duration _duration = Duration.zero;

//   final StreamController<double> _progressController =
//       StreamController<double>.broadcast();

//   bool get isPlaying => _isPlaying;
//   Stream<double> get playbackProgress => _progressController.stream;

//   TtsPlayerService() {
//     _player.onPlayerComplete.listen((_) {
//       _isPlaying = false;
//       _progressController.add(0.0);
//       onPlaybackDone?.call();
//     });
//     _player.onDurationChanged.listen((d) {
//       _duration = d;
//     });
//   }

//   void addChunk(Uint8List chunk) {
//     _buffer.add(chunk);
//   }

//   Future<void> finishStream() async {
//     if (_buffer.isEmpty) return;
//     final totalSize = _buffer.fold<int>(0, (s, c) => s + c.length);
//     final all = Uint8List(totalSize);
//     var offset = 0;
//     for (final chunk in _buffer) {
//       all.setRange(offset, offset + chunk.length, chunk);
//       offset += chunk.length;
//     }
//     _buffer.clear();
//     await _playBytes(all);
//   }

//   Future<void> _playBytes(Uint8List audioBytes) async {
//     try {
//       final dir = await getTemporaryDirectory();
//       final file = File('${dir.path}/lingxi_tts.wav');
//       await file.parent.create(recursive: true);
//       await file.writeAsBytes(audioBytes);
//       await _player.stop();
//       _posSub?.cancel();
//       _isPlaying = true;
//       onPlaybackDone?.call();
//       await _player.play(DeviceFileSource(file.path));
//       _posSub = _player.onPositionChanged.listen((pos) {
//         if (_duration.inMilliseconds > 0) {
//           _progressController.add(
//               pos.inMilliseconds / _duration.inMilliseconds);
//         }
//       });
//     } catch (e) {
//       _isPlaying = false;
//       _progressController.add(0.0);
//       onPlaybackDone?.call();
//       debugPrint('TTS play error: $e');
//     }
//   }

//   Future<void> stop() async {
//     _isPlaying = false;
//     _buffer.clear();
//     _posSub?.cancel();
//     _progressController.add(0.0);
//     onPlaybackDone?.call();
//     await _player.stop();
//   }

//   void dispose() {
//     _isPlaying = false;
//     _buffer.clear();
//     _posSub?.cancel();
//     _progressController.add(0.0);
//     _progressController.close();
//     _player.dispose();
//   }
// }
// ============================================================
