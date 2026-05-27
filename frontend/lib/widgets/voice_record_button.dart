import 'package:flutter/material.dart';

class VoiceRecordButton extends StatefulWidget {
  final void Function(bool isRecording)? onRecordingChanged;
  const VoiceRecordButton({super.key, this.onRecordingChanged});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  bool _recording = false;

  void _toggleRecording() {
    setState(() => _recording = !_recording);
    widget.onRecordingChanged?.call(_recording);
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
