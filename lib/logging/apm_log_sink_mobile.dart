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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE IF NOT EXISTS apm_logs (
  id TEXT PRIMARY KEY,
  createdUtcIso TEXT NOT NULL,
  level TEXT NOT NULL,
  category TEXT NULL,
  message TEXT NOT NULL,
  error TEXT NULL,
  stackTrace TEXT NULL
)
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_apm_logs_createdUtcIso ON apm_logs(createdUtcIso)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_apm_logs_level ON apm_logs(level)',
        );
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
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
