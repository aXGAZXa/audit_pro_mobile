import 'dart:io';

import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_payload_builder.dart';

class HnaFormDeleteService {
  Future<void> deleteFormAndAttachments({
    required int formId,
    DatabaseHelper? db,
  }) async {
    final database = db ?? DatabaseHelper.instance;

    final localPaths = <String>{};

    try {
      final payload = await HnaSubmissionPayloadBuilder.build(
        formId: formId,
        db: database,
        submittedAt: DateTime.now(),
      );

      final hna = payload?['hna'];
      if (hna is Map) {
        final attachments = hna['attachments'];
        if (attachments is List) {
          for (final a in attachments.whereType<Map>()) {
            final p = a['localPath']?.toString().trim();
            if (p == null || p.isEmpty) continue;
            localPaths.add(p);
          }
        }
      }
    } catch (e, st) {
      ApmLogger.warning(
        'Attachment enumeration failed for delete formId=$formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Delete',
        error: e,
        stackTrace: st,
      );
      // Best-effort cleanup: proceed with DB delete even if attachment discovery
      // fails.
    }

    var deleted = 0;
    for (final path in localPaths) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          deleted += 1;
        }
      } catch (e) {
        ApmLogger.warning(
          'Failed to delete attachment formId=$formId path=$path: {Error}',
          args: [e.toString()],
          category: 'HNA/Delete',
          error: e,
        );
      }
    }

    await database.deleteForm(formId);

    ApmLogger.info(
      'Deleted formId=$formId attachments=$deleted',
      category: 'HNA/Delete',
    );
  }
}
