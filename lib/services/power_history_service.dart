import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/power_sample.dart';

class PowerHistoryService {
  static const int retentionDays = 90;

  final Database _db;

  PowerHistoryService._(this._db);

  static Future<PowerHistoryService> create() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'power_history.db');

    final db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE power_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp_utc TEXT NOT NULL,
            watts REAL NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_power_samples_timestamp ON power_samples(timestamp_utc)',
        );
      },
    );

    final service = PowerHistoryService._(db);
    await service.pruneOldSamples();
    return service;
  }

  Future<void> insertSample(PowerSample sample) async {
    await _db.insert('power_samples', {
      'timestamp_utc': sample.timestamp.toUtc().toIso8601String(),
      'watts': sample.watts,
    });
  }

  Future<List<PowerSample>> loadRange({required ChartRange range}) async {
    final cutoff =
        DateTime.now().toUtc().subtract(range.duration).toIso8601String();

    final rows = await _db.query(
      'power_samples',
      columns: ['timestamp_utc', 'watts'],
      where: 'timestamp_utc >= ?',
      whereArgs: [cutoff],
      orderBy: 'timestamp_utc ASC',
    );

    return rows
        .map(
          (row) => PowerSample(
            timestamp: DateTime.parse(row['timestamp_utc'] as String).toLocal(),
            watts: (row['watts'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> pruneOldSamples() async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: retentionDays))
        .toIso8601String();

    await _db.delete(
      'power_samples',
      where: 'timestamp_utc < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> dispose() async {
    await _db.close();
  }
}
