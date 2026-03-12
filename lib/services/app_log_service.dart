import 'dart:collection';

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  String toConsoleLine() {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss][${level.name.toUpperCase()}][$source] $message';
  }
}

class AppLogService {
  final int _maxEntries;
  final Queue<AppLogEntry> _entries = ListQueue<AppLogEntry>();

  AppLogService({int maxEntries = 250}) : _maxEntries = maxEntries;

  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  AppLogEntry? get latest => _entries.isEmpty ? null : _entries.last;

  void debug(String source, String message) {
    _add(level: AppLogLevel.debug, source: source, message: message);
  }

  void info(String source, String message) {
    _add(level: AppLogLevel.info, source: source, message: message);
  }

  void warning(String source, String message) {
    _add(level: AppLogLevel.warning, source: source, message: message);
  }

  void error(String source, String message) {
    _add(level: AppLogLevel.error, source: source, message: message);
  }

  void _add({
    required AppLogLevel level,
    required String source,
    required String message,
  }) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    if (!kReleaseMode ||
        level == AppLogLevel.warning ||
        level == AppLogLevel.error) {
      debugPrint(entry.toConsoleLine());
    }
  }
}
