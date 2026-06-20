import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'apm_log_entry.dart';
import 'apm_log_sink.dart';

class ApmLogSinkImpl implements ApmLogSink {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'audit_pro_mobile_logs.db');

    _db = await openDatabase(
      dbPath,
      // v2 adds the `uploaded` high-water flag used by the device-log upload
      // service to track which rows have been POSTed to the server.
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE IF NOT EXISTS apm_logs (
  id TEXT PRIMARY KEY,
  createdUtcIso TEXT NOT NULL,
  level TEXT NOT NULL,
  category TEXT NULL,
  message TEXT NOT NULL,
  error TEXT NULL,
  stackTrace TEXT NULL,
  uploaded INTEGER NOT NULL DEFAULT 0
)
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_apm_logs_createdUtcIso ON apm_logs(createdUtcIso)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_apm_logs_level ON apm_logs(level)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_apm_logs_uploaded ON apm_logs(uploaded)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE apm_logs ADD COLUMN uploaded INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_apm_logs_uploaded ON apm_logs(uploaded)',
          );
        }
      },
    );
  }

  @override
  Future<void> write(ApmLogEntry entry) async {
    final db = _db;
    if (db == null) return;

    await db.insert('apm_logs', {
      'id': entry.id,
      'createdUtcIso': entry.createdUtcIso,
      'level': entry.level.name,
      'category': entry.category,
      'message': entry.message,
      'error': entry.error,
      'stackTrace': entry.stackTrace,
      'uploaded': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ApmLogEntry>> readUnuploaded({int limit = 50}) async {
    final db = _db;
    if (db == null) return <ApmLogEntry>[];

    final rows = await db.query(
      'apm_logs',
      where: 'uploaded = 0',
      orderBy: 'createdUtcIso ASC',
      limit: limit,
    );

    return rows.map((r) {
      return ApmLogEntry(
        id: r['id'] as String,
        createdUtcIso: r['createdUtcIso'] as String,
        level: _parseLevel(r['level'] as String?),
        category: r['category'] as String?,
        message: (r['message'] as String?) ?? '',
        error: r['error'] as String?,
        stackTrace: r['stackTrace'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> markUploaded(List<String> ids) async {
    final db = _db;
    if (db == null || ids.isEmpty) return;

    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE apm_logs SET uploaded = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  static ApmLogLevel _parseLevel(String? value) {
    switch (value) {
      case 'fatal':
        return ApmLogLevel.fatal;
      case 'error':
        return ApmLogLevel.error;
      case 'warning':
      default:
        return ApmLogLevel.warning;
    }
  }
}
