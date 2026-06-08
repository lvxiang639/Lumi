import 'package:flutter/foundation.dart';

class AppLogger {
  static const _prefix = '🦊 灵犀';

  static void info(String msg, {String? tag}) {
    debugPrint('$_prefix${tag != null ? '[$tag]' : ''} $msg');
  }

  static void ws(String msg) => info(msg, tag: 'WS');
  static void api(String msg) => info(msg, tag: 'API');
  static void chat(String msg) => info(msg, tag: 'CHAT');
  static void error(String msg, [Object? e, StackTrace? st]) {
    debugPrint('$_prefix[ERR] $msg');
    if (e != null) debugPrint('  └─ $e');
    if (st != null) debugPrint('  └─ $st');
  }
  static void lifecycle(String msg) => info(msg, tag: 'LIFE');
}
