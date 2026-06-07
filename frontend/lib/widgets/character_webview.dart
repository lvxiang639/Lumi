import 'dart:convert' show base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import 'character_html.dart';
import 'character_view.dart';

/// Character display widget (simplified — no mouth animation).
/// Uses WebView (SVG/CSS character) on iOS/Android where transparent WebView
/// is supported, and PNG-based CharacterView on macOS where WKWebView's
/// setOpaque is unimplemented.
class CharacterWebView extends StatefulWidget {
  final String animState;
  final String emotion;
  final double emotionIntensity;

  const CharacterWebView({
    super.key,
    this.animState = 'idle',
    this.emotion = 'calm',
    this.emotionIntensity = 0.0,
  });

  @override
  State<CharacterWebView> createState() => _CharacterWebViewState();
}

class _CharacterWebViewState extends State<CharacterWebView> {
  // Use 3D WebView on all platforms
  static const bool _usePng = false;

  // WebView state (iOS/Android only)
  WebViewController? _controller;
  bool _ready = false;
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
            onPageFinished: (_) async {
              _ready = true;
              _syncToJs();
              // Inject bundled VRM model as base64
              try {
                final bytes = await rootBundle
                    .load('assets/character/model.vrm');
                final b64 = base64Encode(bytes.buffer.asUint8List());
                await _controller!.runJavaScript(
                    'if(window.loadModelBase64)window.loadModelBase64("$b64")');
              } catch (_) {
                // fallback character renders automatically
              }
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
        (old.animState != widget.animState ||
         old.emotion != widget.emotion ||
         old.emotionIntensity != widget.emotionIntensity)) {
      _syncToJs();
    }
  }

  void _syncToJs() {
    if (!_ready || _controller == null) return;

    final state = widget.animState;
    if (state != _lastState) {
      _lastState = state;
      _controller!.runJavaScript(
          "if(window.setAnimState)window.setAnimState('$state')");
    }

    final emotion = widget.emotion;
    if (emotion != _lastEmotion) {
      _lastEmotion = emotion;
      _controller!.runJavaScript(
          "if(window.setEmotion)window.setEmotion('$emotion')");
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
