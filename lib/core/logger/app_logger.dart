import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String _tag;

  AppLogger(this._tag, {this.enabled = true});

  final bool enabled;

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, message, error, stack);

  void _log(LogLevel level, String message, [Object? error, StackTrace? stack]) {
    if (!enabled) return;
    final prefix = level.name.toUpperCase().padRight(7);
    final line = '[$prefix] $_tag: $message';
    switch (level) {
      case LogLevel.debug:
      case LogLevel.info:
        debugPrint(line);
      case LogLevel.warning:
        debugPrint('\x1B[33m$line\x1B[0m');
      case LogLevel.error:
        debugPrint('\x1B[31m$line\x1B[0m');
        if (error != null) debugPrint('$error');
        if (stack != null) debugPrint('$stack');
    }
  }
}
