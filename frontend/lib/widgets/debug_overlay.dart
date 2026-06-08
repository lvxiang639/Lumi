import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/logger.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;
  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _visible = false;
  final _scrollCtrl = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_visible) _logPanel(),
      // Toggle button
      Positioned(
        right: 8, bottom: 120,
        child: GestureDetector(
          onLongPress: () => setState(() => _visible = !_visible),
          onTap: () {
            if (_visible) _scrollCtrl.jumpTo(0);
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _visible ? AppColors.accent : Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bug_report, color: Colors.white, size: 16),
          ),
        ),
      ),
    ]);
  }

  Widget _logPanel() {
    final logs = AppLogger.buffer;
    return Positioned(
      top: 60, left: 4, right: 4, bottom: 200,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF0081220),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                const Text('🦊 日志', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _visible = false),
                  child: const Icon(Icons.close, color: Colors.white54, size: 16)),
              ])),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final e = logs[i];
                  final color = e.tag == 'ERR' ? Colors.red : e.tag == 'VOICE' ? Colors.amber : e.tag == 'API' ? Colors.cyan : Colors.white54;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: Text(
                      '[${e.tag}] ${e.msg}',
                      style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
