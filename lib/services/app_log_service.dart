import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
  final Duration _flushDelay;
  File? _logFile;
  final List<String> _pendingLines = [];
  bool _flushInProgress = false;
  Completer<void>? _flushCompleter;
  Timer? _flushTimer;

  AppLogService(
      {int maxEntries = 250, Duration flushDelay = const Duration(seconds: 2)})
      : _maxEntries = maxEntries,
        _flushDelay = flushDelay;

  /// Call once at startup to enable on-disk persistence for logs.
  Future<void> init({String? basePath}) async {
    final base = basePath ?? await getDatabasesPath();
    final path = p.join(base, 'app_logs.txt');
    _logFile = File(path);
    try {
      await _logFile!.create(recursive: true);
    } catch (_) {
      // ignore
    }
  }

  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  AppLogEntry? get latest => _entries.isEmpty ? null : _entries.last;

  /// Returns the currently active log file path, if initialized.
  String? get logFilePath => _logFile?.path;

  Future<String> readAll() async {
    final file = _logFile;
    if (file == null) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<void> clear() async {
    _entries.clear();
    _pendingLines.clear();
    _flushTimer?.cancel();
    _flushTimer = null;

    final file = _logFile;
    if (file == null) return;
    try {
      await file.writeAsString('');
    } catch (_) {
      // ignore
    }
  }

  /// Flush any pending log lines to disk.
  Future<void> flush() async {
    await _flushPending();
  }

  /// Clean up internal timers; should be called when the owning object is disposed.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

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
    // Redact accidental plain text passwords in URLs or log messages
    final redactedMessage = message.replaceAllMapped(
        RegExp(r'(password[:=])([^\s&]+)', caseSensitive: false),
        (match) => '${match.group(1)}***');

    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: redactedMessage,
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

    _pendingLines.add('${entry.toConsoleLine()}\n');
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushDelay == Duration.zero) {
      unawaited(_flushPending());
      return;
    }

    if (_flushTimer != null) return;
    _flushTimer = Timer(_flushDelay, () async {
      _flushTimer = null;
      await _flushPending();
    });
  }

  Future<void> _flushPending() async {
    if (_flushInProgress) {
      return _flushCompleter?.future ?? Future.value();
    }

    _flushInProgress = true;
    _flushCompleter = Completer<void>();

    try {
      final file = _logFile;
      if (file == null) {
        _pendingLines.clear();
        return;
      }

      while (_pendingLines.isNotEmpty) {
        final toWrite = _pendingLines.join();
        _pendingLines.clear();

        try {
          await file.writeAsString(toWrite, mode: FileMode.append, flush: true);
        } catch (_) {
          // Ignore failures - logging should never crash the app.
        }
      }
    } finally {
      _flushInProgress = false;
      _flushCompleter?.complete();
      _flushCompleter = null;
    }
  }
}
