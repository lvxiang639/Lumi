import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'character_html.dart';
import 'character_view.dart';

/// Character display widget. Uses WebView (SVG/CSS character) on iOS/Android
/// where transparent WebView is supported, and PNG-based CharacterView on
/// macOS where WKWebView's setOpaque is unimplemented.
class CharacterWebView extends StatefulWidget {
  final double mouthOpen;
  final String animState;
  final String emotion;
  final double emotionIntensity;

  const CharacterWebView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
    this.emotion = 'calm',
    this.emotionIntensity = 0.0,
  });

  @override
  State<CharacterWebView> createState() => _CharacterWebViewState();
}

class _CharacterWebViewState extends State<CharacterWebView> {
  // macOS fallback delegates to PNG-based view
  late final bool _usePng = Platform.isMacOS;

  // WebView state (iOS/Android only)
  WebViewController? _controller;
  bool _ready = false;
  double _lastMouth = -1;
  String _lastState = '';
  String _lastEmotion = '';
  double _lastEmotionIntensity = -1;

  @override
  void initState() {
    super.initState();
    if (!_usePng) _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _ready = true;
              _syncToJs();
            },
          ),
        );

      await _controller!.loadHtmlString(kCharacterHtml);
    } catch (e) {
      debugPrint('CharacterWebView init failed: $e');
    }
  }

  @override
  void didUpdateWidget(CharacterWebView old) {
    super.didUpdateWidget(old);
    if (!_usePng &&
        (old.mouthOpen != widget.mouthOpen ||
         old.animState != widget.animState ||
         old.emotion != widget.emotion ||
         old.emotionIntensity != widget.emotionIntensity)) {
      _syncToJs();
    }
  }

  void _syncToJs() {
    if (!_ready || _controller == null) return;

    final mouth = widget.mouthOpen.clamp(0.0, 1.0);
    if (mouth != _lastMouth) {
      _lastMouth = mouth;
      _controller!.runJavaScript(
          'if(window.updateMouth)window.updateMouth(${mouth.toStringAsFixed(3)})');
    }

    final state = widget.animState;
    if (state != _lastState) {
      _lastState = state;
      _controller!.runJavaScript(
          "if(window.setState)window.setState('$state')");
    }

    final emotion = widget.emotion;
    if (emotion != _lastEmotion) {
      _lastEmotion = emotion;
      _controller!.runJavaScript(
          "if(window.updateEmotion)window.updateEmotion('$emotion')");
    }

    final intensity = widget.emotionIntensity.clamp(0.0, 1.0);
    if (intensity != _lastEmotionIntensity) {
      _lastEmotionIntensity = intensity;
      _controller!.runJavaScript(
          'if(window.updateEmotionIntensity)window.updateEmotionIntensity(${intensity.toStringAsFixed(3)})');
    }
  }

  @override
  Widget build(BuildContext context) {
    // macOS: use PNG character (transparent WebView unsupported)
    if (_usePng) {
      return CharacterView(
        mouthOpen: widget.mouthOpen,
        animState: widget.animState,
        emotion: widget.emotion,
        emotionIntensity: widget.emotionIntensity,
      );
    }

    // iOS/Android: WebView with SVG/CSS character
    if (_controller == null) {
      return const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF7C8FFF)),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}
