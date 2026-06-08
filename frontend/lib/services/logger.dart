import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime time;
  final String tag;
  final String msg;
  LogEntry(this.tag, this.msg) : time = DateTime.now();
}

class AppLogger {
  static final List<LogEntry> _buffer = [];
  static const _maxBuffer = 200;
  static bool showOverlay = false;
  static void Function()? onToggleOverlay;

  static void _add(String tag, String msg) {
    _buffer.insert(0, LogEntry(tag, msg));
    if (_buffer.length > _maxBuffer) _buffer.removeLast();
    debugPrint('🦊[$tag] $msg');
  }

  static List<LogEntry> get buffer => List.unmodifiable(_buffer);

  static void info(String msg, {String tag = 'INFO'}) => _add(tag, msg);
  static void ws(String msg) => _add('WS', msg);
  static void api(String msg) => _add('API', msg);
  static void chat(String msg) => _add('CHAT', msg);
  static void voice(String msg) => _add('VOICE', msg);
  static void error(String msg, [Object? e, StackTrace? st]) {
    _add('ERR', msg);
    if (e != null) _add('ERR', '  └─ $e');
    if (st != null) _add('ERR', '  └─ ${st.toString().split('\n').take(3).join('\n')}');
  }
}
