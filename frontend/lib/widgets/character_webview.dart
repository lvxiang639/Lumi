import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the HTML/CSS anime character in a WebView and bridges
/// Flutter → JavaScript for real-time mouth sync and state changes.
class CharacterWebView extends StatefulWidget {
  final double mouthOpen;
  final String animState;

  const CharacterWebView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
  });

  @override
  State<CharacterWebView> createState() => _CharacterWebViewState();
}

class _CharacterWebViewState extends State<CharacterWebView> {
  WebViewController? _controller;
  bool _ready = false;
  double _lastMouth = -1;
  String _lastState = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
      // setBackgroundColor → setOpaque is unimplemented on macOS WKWebView
      if (!Platform.isMacOS) {
        _controller!.setBackgroundColor(Colors.transparent);
      }
      _controller!
        .setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _ready = true;
              _syncToJs();
            },
          ),
        );

      final html = await rootBundle
          .loadString('assets/character/character.html');
      await _controller!.loadHtmlString(html);
    } catch (e) {
      debugPrint('CharacterWebView init failed: $e');
    }
  }

  @override
  void didUpdateWidget(CharacterWebView old) {
    super.didUpdateWidget(old);
    if (old.mouthOpen != widget.mouthOpen ||
        old.animState != widget.animState) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF7C8FFF),
          ),
        ),
      );
    }

    return WebViewWidget(controller: _controller!);
  }
}
