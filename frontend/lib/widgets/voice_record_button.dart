import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';

class VoiceRecordButton extends StatefulWidget {
  final void Function(String base64Audio)? onAudioReady;
  const VoiceRecordButton({super.key, this.onAudioReady});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioRecorderService _recorder = AudioRecorderService();
  bool _recording = false;

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recording = false;
      if (mounted) setState(() {});
      if (path != null && widget.onAudioReady != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64 = base64Encode(bytes);
          widget.onAudioReady!(base64);
        }
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
      await _recorder.start();
      _recording = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _recording ? Colors.red : Colors.indigo,
          shape: BoxShape.circle,
        ),
        child: Icon(_recording ? Icons.mic : Icons.mic_none, color: Colors.white),
      ),
    );
  }
}
