import 'dart:io';

import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/services/form_edit_session_attachment_endpoints.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FormEditSessionSnapshotHydrator {
  FormEditSessionSnapshotHydrator({
    DatabaseHelper? db,
    PortalApiClient? apiClient,
    FormEditSessionAttachmentEndpoints? attachmentEndpoints,
  }) : db = db ?? DatabaseHelper.instance,
       apiClient =
           apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl),
       attachmentEndpoints =
           attachmentEndpoints ??
           FormEditSessionAttachmentEndpoints.forHnaAssessments();

  final DatabaseHelper db;
  final PortalApiClient apiClient;
  final FormEditSessionAttachmentEndpoints attachmentEndpoints;

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static String _readString(Map<String, dynamic> map, String key) {
    return map[key]?.toString().trim() ?? '';
  }

  static String _inferExtension({
    required String localPath,
    String? contentType,
  }) {
    final lp = localPath.trim().toLowerCase();
    if (lp.endsWith('.png')) return '.png';
    if (lp.endsWith('.jpg') || lp.endsWith('.jpeg')) return '.jpg';
    if (lp.endsWith('.webp')) return '.webp';
    if (lp.endsWith('.heic')) return '.heic';

    final ct = (contentType ?? '').trim().toLowerCase();
    if (ct == 'image/png') return '.png';
    if (ct == 'image/jpeg') return '.jpg';
    if (ct == 'image/webp') return '.webp';
    if (ct == 'image/heic') return '.heic';

    return '.img';
  }

  static dynamic _rewriteNode(dynamic node, Map<String, String> rewrite) {
    if (node is String) {
      final direct = rewrite[node];
      if (direct != null) return direct;
      final trimmed = node.trim();
      final viaTrim = rewrite[trimmed];
      return viaTrim ?? node;
    }

    if (node is List) {
      return node.map((e) => _rewriteNode(e, rewrite)).toList();
    }

    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        out[k.toString()] = _rewriteNode(v, rewrite);
      });
      return out;
    }

    return node;
  }

  static dynamic _cleanupNode(dynamic node) {
    if (node is List) {
      final cleaned = node
          .map(_cleanupNode)
          .where((e) => !(e is String && e.trim().isEmpty))
          .toList();
      return cleaned;
    }

    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        out[k.toString()] = _cleanupNode(v);
      });
      return out;
    }

    return node;
  }

  Future<Map<String, dynamic>> _tryHydrateAttachmentsFromPortal({
    required Map<String, dynamic> assessment,
    required String token,
    required String submissionId,
  }) async {
    final hna = _asMap(assessment['hna']);
    final attachmentsRaw = hna['attachments'];
    if (attachmentsRaw is! List) return assessment;

    final attachments = attachmentsRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (attachments.isEmpty) return assessment;

    ApmLogger.info(
      'Edit-session hydrate attachments start submissionId=$submissionId total=${attachments.length}',
      category: 'HNA/EditHydrate',
    );

    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(
      p.join(
        appDir.path,
        attachmentEndpoints.localFolderName,
        submissionId.trim(),
      ),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    ApmLogger.debug(
      'Edit-session hydrate attachments destDir=${destDir.path}',
      category: 'HNA/EditHydrate',
    );

    final rewrite = <String, String>{};

    var reusedLocal = 0;
    var copiedToStable = 0;
    var usedStableCache = 0;
    var downloaded = 0;
    var failed = 0;

    for (final a in attachments) {
      final attachmentId = (a['id'] ?? '').toString().trim();
      final oldPath = (a['localPath'] ?? '').toString();
      final oldPathTrimmed = oldPath.trim();
      if (attachmentId.isEmpty || oldPathTrimmed.isEmpty) continue;

      final ext = _inferExtension(
        localPath: oldPathTrimmed,
        contentType: a['contentType']?.toString(),
      );
      final destPath = p.join(destDir.path, '$attachmentId$ext');

      try {
        // Same-device optimization: if the original file still exists locally,
        // copy it into our stable edit-session folder and avoid a network call.
        final existingLocal = File(oldPathTrimmed);
        if (await existingLocal.exists()) {
          String finalPath;
          try {
            final destFile = File(destPath);
            if (!await destFile.exists()) {
              await existingLocal.copy(destPath);
              copiedToStable += 1;
            }

            final copied = File(destPath);
            finalPath = await copied.exists()
                ? copied.path
                : existingLocal.path;
          } catch (_) {
            finalPath = existingLocal.path;
          }

          reusedLocal += 1;
          ApmLogger.debug(
            'Hydrate attachment reuse-local submissionId=$submissionId attachmentId=$attachmentId oldPath=$oldPathTrimmed finalPath=$finalPath',
            category: 'HNA/EditHydrate',
          );

          a['localPath'] = finalPath;
          rewrite[oldPath] = finalPath;
          rewrite[oldPathTrimmed] = finalPath;
          continue;
        }

        final file = File(destPath);
        if (await file.exists()) {
          usedStableCache += 1;
          ApmLogger.debug(
            'Hydrate attachment cache-hit submissionId=$submissionId attachmentId=$attachmentId path=$destPath',
            category: 'HNA/EditHydrate',
          );
        } else {
          final bytes = await apiClient.getBytes(
            attachmentEndpoints.contentPath(submissionId, attachmentId),
            bearerToken: token,
          );
          await file.writeAsBytes(bytes, flush: true);
          downloaded += 1;
          ApmLogger.debug(
            'Hydrate attachment downloaded submissionId=$submissionId attachmentId=$attachmentId bytes=${bytes.length} path=$destPath',
            category: 'HNA/EditHydrate',
          );
        }

        a['localPath'] = file.path;
        rewrite[oldPath] = file.path;
        rewrite[oldPathTrimmed] = file.path;
      } catch (e, st) {
        failed += 1;
        // If we can't fetch the attachment, clear stale references so this
        // draft doesn't later fail submission due to missing local files.
        rewrite[oldPath] = '';
        rewrite[oldPathTrimmed] = '';
        ApmLogger.warning(
          'Attachment hydration failed submissionId=$submissionId attachmentId=$attachmentId: {Error}',
          args: [e.toString()],
          category: 'HNA/EditHydrate',
          error: e,
          stackTrace: st,
        );
      }
    }

    ApmLogger.info(
      'Edit-session hydrate attachments complete submissionId=$submissionId reusedLocal=$reusedLocal copiedToStable=$copiedToStable usedStableCache=$usedStableCache downloaded=$downloaded failed=$failed rewriteKeys=${rewrite.length}',
      category: 'HNA/EditHydrate',
    );

    if (rewrite.isEmpty) return assessment;

    // Deep-rewrite any matching old local paths into the newly downloaded paths.
    final rewritten = _rewriteNode(assessment, rewrite);
    final cleaned = _cleanupNode(rewritten);
    return cleaned is Map<String, dynamic>
        ? cleaned
        : Map<String, dynamic>.from(cleaned as Map);
  }

  Future<int> createDraftFromSnapshot({
    required Map<String, dynamic> assessment,
    required String token,
    required String sessionToken,
    required String editRequestId,
    required String submissionId,
    required DateTime? submittedAtUtc,
    required DateTime? expiresAtUtc,
  }) async {
    final hydratedAssessment = await _tryHydrateAttachmentsFromPortal(
      assessment: assessment,
      token: token,
      submissionId: submissionId,
    );

    final hna = _asMap(hydratedAssessment['hna']);
    final summary = _asMap(hna['summary']);
    final form = _asMap(hydratedAssessment['form']);

    final stableFormUuid = _readString(summary, 'formUuid').isNotEmpty
        ? _readString(summary, 'formUuid')
        : _readString(form, 'uuid');

    final formData = _asMap(hna['formData']);

    final stableFriendlyRef = _readString(summary, 'friendlyRef');
    final stableSubmittedAt = _readString(summary, 'submittedAt');

    final submissionSummary = <String, dynamic>{
      if (stableFriendlyRef.isNotEmpty) 'friendlyRef': stableFriendlyRef,
      if (stableSubmittedAt.isNotEmpty)
        'submittedAt': stableSubmittedAt
      else if (submittedAtUtc != null)
        'submittedAt': submittedAtUtc.toUtc().toIso8601String(),
      'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
    };

    formData['submissionSummary'] = submissionSummary;

    formData['editSession'] = {
      'mode': 'edit_requested',
      'sessionToken': sessionToken,
      'editRequestId': editRequestId,
      'submissionId': submissionId,
      if (expiresAtUtc != null) 'expiresAtUtc': expiresAtUtc.toIso8601String(),
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    };

    final assets = _asMap(hna['assets']);
    final observations = _asListOfMaps(hna['observations']);
    final unsafe = _asMap(hna['unsafe']);

    final draftDoc = <String, dynamic>{
      'formData': formData,
      'assets': assets,
      'unsafe': unsafe,
      'observations': observations,
    };

    final newFormId = await db.saveForm(
      formType: kHeatNetworkAssessmentFormType,
      status: 'draft',
      formData: draftDoc,
      uuid: stableFormUuid.isEmpty ? null : stableFormUuid,
    );

    await db.setCurrentFormId(
      formType: kHeatNetworkAssessmentFormType,
      formId: newFormId,
    );

    ApmLogger.info(
      'Hydrated edit-session snapshot to local form formId=$newFormId submissionId=$submissionId editRequestId=$editRequestId',
      category: 'HNA/EditHydrate',
    );

    return newFormId;
  }
}
