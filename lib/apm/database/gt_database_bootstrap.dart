import 'package:flutter/foundation.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../logging/apm_logger.dart';

/// Bootstraps the gtapp_dart [GTDatabaseService] used by the generic
/// (builder-authored) forms runtime for file/image metadata persistence.
///
/// This is SEPARATE from and ADDITIVE to the live CR/HNA persistence in
/// `lib/apm/database/database_helper.dart` (raw sqflite via getDatabasesPath).
/// The hard-coded CR/HNA flows do NOT use GTDatabaseService — only the generic
/// forms image question (ImageQuestionWidget -> MultipleImageCapture ->
/// FileMetadataHelper -> FileStorageService -> GTDatabaseService.saveAsync of a
/// GTImage) does. Without this bootstrap, saving a photo on a generic form fails
/// with: "DatabaseFactory must be set before initializing database".
class GtDatabaseBootstrap {
  static bool _done = false;

  /// Initializes [GTDatabaseService] for the current platform and registers the
  /// models the generic forms image path persists ([GTImage]).
  ///
  /// Safe to call once at startup, after WidgetsFlutterBinding.ensureInitialized().
  /// Never throws — failures are logged so startup is not blocked.
  static Future<void> init() async {
    if (_done) return;
    _done = true;

    // The web build is the form web editor: it has NO local database (images
    // live in R2, resolved via GTFileManagerConfig.remoteImageResolver). Opening
    // sqflite on web needs the unbundled `sqflite_sw.js` worker (404), so never
    // touch the local DB here. Caller (main.dart) already guards on !kIsWeb;
    // this is a defensive second guard.
    if (kIsWeb) {
      ApmLogger.info(
        'GTDatabaseService bootstrap skipped on web (no local DB; images via R2)',
        category: 'Startup',
      );
      return;
    }

    try {
      final db = GTDatabaseService.instance;

      db.databaseFactory = sqflite.databaseFactory;
      final appDir = await getApplicationDocumentsDirectory();
      db.databasePath = p.join(appDir.path, 'audit_pro_mobile.db');

      db.configure(
        const DatabaseConfiguration(
          resetMode: DatabaseResetMode.none,
          version: 1,
        ),
      );

      await _registerModels(db);

      // Force-init so the table is created up-front (and any error surfaces here
      // rather than on first photo save). Wrapped so startup never crashes.
      await db.database;

      ApmLogger.info(
        'GTDatabaseService bootstrapped (web: {Web}, path: {Path})',
        args: [kIsWeb, db.databasePath],
        category: 'Startup',
      );
    } catch (e, st) {
      ApmLogger.warning(
        'GTDatabaseService bootstrap failed: {Error}',
        args: [e.toString()],
        category: 'Startup',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Registers the file-metadata model persisted by the generic forms image
  /// question. The fluent `register<T>()` builder does not expose
  /// `filePathPropertyName`, so we use [GTDatabaseService.registerModel] directly
  /// to enable automatic physical-file cleanup on delete (and orphan cleanup).
  static Future<void> _registerModels(GTDatabaseService db) async {
    final result = await db.registerModel(
      ModelMetadata(
        modelType: GTImage,
        tableName: 'gt_images',
        scalarProperties: const [
          'id',
          'fileName',
          'localPath',
          'mimeType',
          'fileSizeBytes',
          'extension',
          'fileType',
          'isCompressed',
          'originalSizeBytes',
          'compressionQuality',
          'createdAt',
          'modifiedAt',
          'lastAccessedAt',
          'relatedEntityId',
          'relatedEntityType',
          'isReadOnly',
          'isHidden',
          'width',
          'height',
          'orientation',
          'thumbnailBase64',
          'thumbnailSizeBytes',
          'thumbnailPath',
          'checksum',
        ],
        // Explicit INTEGER affinity for numeric columns so values round-trip as
        // ints (GTImage.fromMap casts these with `as int` / `as int?`).
        columnTypes: const {
          'fileSizeBytes': 'INTEGER',
          'isCompressed': 'INTEGER',
          'originalSizeBytes': 'INTEGER',
          'compressionQuality': 'INTEGER',
          'isReadOnly': 'INTEGER',
          'isHidden': 'INTEGER',
          'width': 'INTEGER',
          'height': 'INTEGER',
          'thumbnailSizeBytes': 'INTEGER',
        },
        indexedProperties: const ['relatedEntityId'],
        // Enables automatic physical-file deletion when metadata is deleted.
        filePathPropertyName: 'localPath',
        fromMapFactory: (map) => GTImage.fromMap(map),
      ),
    );

    if (!result.success) {
      ApmLogger.warning(
        'GTImage model registration failed: {Error}',
        args: [result.message],
        category: 'Startup',
      );
    }
  }
}
