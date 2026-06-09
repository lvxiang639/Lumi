import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _online = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online != _online && mounted) {
        setState(() => _online = online);
      }
    } catch (_) {
      if (_online && mounted) setState(() => _online = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (!_online)
        MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          backgroundColor: AppColors.danger.withValues(alpha: 0.9),
          content: const Row(children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('网络连接已断开', style: TextStyle(color: Colors.white, fontSize: 13))),
          ]),
          actions: [
            TextButton(
              onPressed: _check,
              child: const Text('重试', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      Expanded(child: widget.child),
    ]);
  }
}
