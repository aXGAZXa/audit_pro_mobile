import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_form_delete_service.dart';

class HnaRetentionCleanupService {
  HnaRetentionCleanupService({
    DatabaseHelper? db,
    HnaFormDeleteService? deleteService,
  }) : _db = db ?? DatabaseHelper.instance,
       _deleteService = deleteService ?? HnaFormDeleteService();

  final DatabaseHelper _db;
  final HnaFormDeleteService _deleteService;

  Future<void> runBestEffort({
    Duration retention = const Duration(days: 7),
  }) async {
    try {
      final index = await _db.getFormsIndex(
        formType: kHeatNetworkAssessmentFormType,
        statuses: const ['sent'],
      );

      final now = DateTime.now();
      final toDelete = <int>[];

      for (final row in index) {
        final id = row['id'];
        final updatedAtRaw = row['updated_at']?.toString();
        if (id is! int) continue;
        if (updatedAtRaw == null || updatedAtRaw.trim().isEmpty) continue;

        final updatedAt = DateTime.tryParse(updatedAtRaw);
        if (updatedAt == null) continue;

        if (now.difference(updatedAt) > retention) {
          toDelete.add(id);
        }
      }

      if (toDelete.isEmpty) {
        ApmLogger.debug(
          'Retention cleanup: nothing to delete',
          category: 'HNA/Retention',
        );
        return;
      }

      ApmLogger.info(
        'Retention cleanup: deleting ${toDelete.length} sent forms',
        category: 'HNA/Retention',
      );

      for (final id in toDelete) {
        try {
          await _deleteService.deleteFormAndAttachments(formId: id, db: _db);
        } catch (e) {
          ApmLogger.warning(
            'Retention delete failed formId=$id: {Error}',
            args: [e.toString()],
            category: 'HNA/Retention',
            error: e,
          );
        }
      }
    } catch (e, st) {
      ApmLogger.warning(
        'Retention cleanup failed: {Error}',
        args: [e.toString()],
        category: 'HNA/Retention',
        error: e,
        stackTrace: st,
      );
    }
  }
}
