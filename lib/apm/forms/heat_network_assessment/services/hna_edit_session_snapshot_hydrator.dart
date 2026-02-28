import 'dart:io';

import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/models/communal_control.dart';
import 'package:audit_pro_mobile/apm/models/dhw_plant.dart';
import 'package:audit_pro_mobile/apm/models/dwelling_inspection.dart';
import 'package:audit_pro_mobile/apm/models/heat_generator.dart';
import 'package:audit_pro_mobile/apm/models/heat_meter.dart';
import 'package:audit_pro_mobile/apm/models/plate_heat_exchanger.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HnaEditSessionSnapshotHydrator {
  HnaEditSessionSnapshotHydrator({
    DatabaseHelper? db,
    PortalApiClient? apiClient,
  }) : db = db ?? DatabaseHelper.instance,
       apiClient =
           apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final DatabaseHelper db;
  final PortalApiClient apiClient;

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

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static DateTime? _tryParseDate(dynamic value) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static String _readString(Map<String, dynamic> map, String key) {
    return map[key]?.toString().trim() ?? '';
  }

  static String? _readNullableString(Map<String, dynamic> map, String key) {
    final s = _readString(map, key);
    return s.isEmpty ? null : s;
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
      p.join(appDir.path, 'hna_attachments', submissionId.trim()),
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
            '/api/hna/assessments/$submissionId/attachments/$attachmentId/content',
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

    final newFormId = await db.saveForm(
      formType: 'heat_network_assessment',
      status: 'draft',
      formData: formData,
      uuid: stableFormUuid.isEmpty ? null : stableFormUuid,
    );

    await db.setCurrentFormId(
      formType: 'heat_network_assessment',
      formId: newFormId,
    );

    final assets = _asMap(hna['assets']);

    // Assets.
    for (final m in _asListOfMaps(assets['heatMeters'])) {
      await db.saveHeatMeter(
        HeatMeter(
          formId: newFormId,
          meterType: _readString(m, 'meterType'),
          make: _readString(m, 'make'),
          model: _readString(m, 'model'),
          location: _readString(m, 'location'),
          ageRange: _readString(m, 'ageRange'),
          serialNumber: _readNullableString(m, 'serialNumber'),
          operational: _readString(m, 'operational'),
          reading: _readNullableString(m, 'reading'),
          relatedAssetType: _readNullableString(m, 'relatedAssetType'),
          relatedAssetId: _tryParseInt(m['relatedAssetId']),
          imagePaths: _asStringList(m['imagePaths']),
          createdAt: _tryParseDate(m['createdAt']),
          updatedAt: _tryParseDate(m['updatedAt']),
        ),
      );
    }

    for (final p in _asListOfMaps(assets['plateHeatExchangers'])) {
      await db.savePlateHeatExchanger(
        PlateHeatExchanger(
          formId: newFormId,
          location: _readString(p, 'location'),
          make: _readString(p, 'make'),
          model: _readString(p, 'model'),
          serialNumber: _readNullableString(p, 'serialNumber'),
          capacity: _readNullableString(p, 'capacity'),
          ageRange: _readString(p, 'ageRange'),
          condition: _readString(p, 'condition'),
          insulationCondition: _readNullableString(p, 'insulationCondition'),
          freeOfLeaks: _readNullableString(p, 'freeOfLeaks'),
          hasIsolationValves: _readNullableString(p, 'hasIsolationValves'),
          hasTempGauges: _readNullableString(p, 'hasTempGauges'),
          hasIndividualMeter: _readNullableString(p, 'hasIndividualMeter'),
          imagePaths: _asStringList(p['imagePaths']),
          createdAt: _tryParseDate(p['createdAt']),
          updatedAt: _tryParseDate(p['updatedAt']),
        ),
      );
    }

    for (final g in _asListOfMaps(assets['heatGenerators'])) {
      await db.saveHeatGenerator(
        HeatGenerator(
          formId: newFormId,
          generatorType: _readString(g, 'generatorType'),
          fuelType: _readString(g, 'fuelType'),
          location: _readString(g, 'location'),
          make: _readString(g, 'make'),
          model: _readString(g, 'model'),
          serialNumber: _readNullableString(g, 'serialNumber'),
          capacity: _readNullableString(g, 'capacity'),
          ageRange: _readString(g, 'ageRange'),
          condition: _readString(g, 'condition'),
          operational: _readNullableString(g, 'operational'),
          hasIndividualMeter: _readNullableString(g, 'hasIndividualMeter'),
          imagePaths: _asStringList(g['imagePaths']),
          createdAt: _tryParseDate(g['createdAt']),
          updatedAt: _tryParseDate(g['updatedAt']),
        ),
      );
    }

    for (final d in _asListOfMaps(assets['dhwPlants'])) {
      await db.saveDhwPlant(
        DhwPlant(
          formId: newFormId,
          plantType: _readString(d, 'plantType'),
          fuelType: _readNullableString(d, 'fuelType'),
          location: _readString(d, 'location'),
          make: _readString(d, 'make'),
          model: _readString(d, 'model'),
          serialNumber: _readNullableString(d, 'serialNumber'),
          capacity: _readNullableString(d, 'capacity'),
          heatInput: _readNullableString(d, 'heatInput'),
          ageRange: _readString(d, 'ageRange'),
          condition: _readString(d, 'condition'),
          operational: _readNullableString(d, 'operational'),
          imagePaths: _asStringList(d['imagePaths']),
          createdAt: _tryParseDate(d['createdAt']),
          updatedAt: _tryParseDate(d['updatedAt']),
        ),
      );
    }

    for (final c in _asListOfMaps(assets['communalControls'])) {
      await db.saveCommunalControl(
        CommunalControl(
          formId: newFormId,
          controlType: _readString(c, 'controlType'),
          location: _readNullableString(c, 'location'),
          make: _readNullableString(c, 'make'),
          model: _readNullableString(c, 'model'),
          serialNumber: _readNullableString(c, 'serialNumber'),
          condition: _readNullableString(c, 'condition'),
          operational: _readNullableString(c, 'operational'),
          imagePaths: _asStringList(c['imagePaths']),
          createdAt: _tryParseDate(c['createdAt']),
          updatedAt: _tryParseDate(c['updatedAt']),
        ),
      );
    }

    for (final di in _asListOfMaps(assets['dwellingInspections'])) {
      await db.saveDwellingInspection(
        DwellingInspection(
          formId: newFormId,
          location: _readString(di, 'location'),
          heatingType: _readNullableString(di, 'heatingType'),
          heatGeneratorType: _readNullableString(di, 'heatGeneratorType'),
          heatGeneratorFuelType: _readNullableString(
            di,
            'heatGeneratorFuelType',
          ),
          heatDistributionType: _readNullableString(di, 'heatDistributionType'),
          dhwType: _readNullableString(di, 'dhwType'),
          dhwGeneratorType: _readNullableString(di, 'dhwGeneratorType'),
          dhwGeneratorFuelType: _readNullableString(di, 'dhwGeneratorFuelType'),
          dhwCommunalType: _readNullableString(di, 'dhwCommunalType'),
          heatingControls: _asStringList(di['heatingControls']),
          heatingControlsOther: _readNullableString(di, 'heatingControlsOther'),
          heatingNotes: _readNullableString(di, 'heatingNotes'),
          heatingImagePaths: _asStringList(di['heatingImagePaths']),
          dhwControls: _asStringList(di['dhwControls']),
          dhwControlsOther: _readNullableString(di, 'dhwControlsOther'),
          dhwNotes: _readNullableString(di, 'dhwNotes'),
          dhwImagePaths: _asStringList(di['dhwImagePaths']),
          heatingMetered: _readNullableString(di, 'heatingMetered'),
          heatingSubMeterFeasible: _readNullableString(
            di,
            'heatingSubMeterFeasible',
          ),
          heatingSubMeterFeasibilityReason: _readNullableString(
            di,
            'heatingSubMeterFeasibilityReason',
          ),
          heatingSubMeterEvidenceImages: _asStringList(
            di['heatingSubMeterEvidenceImages'],
          ),
          dhwMetered: _readNullableString(di, 'dhwMetered'),
          dhwSubMeterFeasible: _readNullableString(di, 'dhwSubMeterFeasible'),
          dhwSubMeterFeasibilityReason: _readNullableString(
            di,
            'dhwSubMeterFeasibilityReason',
          ),
          dhwSubMeterEvidenceImages: _asStringList(
            di['dhwSubMeterEvidenceImages'],
          ),
          hiuMake: _readNullableString(di, 'hiuMake'),
          hiuModel: _readNullableString(di, 'hiuModel'),
          hiuSerialNumber: _readNullableString(di, 'hiuSerialNumber'),
          condition: _readNullableString(di, 'condition'),
          operational: _readNullableString(di, 'operational'),
          imagePaths: _asStringList(di['imagePaths']),
          createdAt: _tryParseDate(di['createdAt']),
          updatedAt: _tryParseDate(di['updatedAt']) ?? DateTime.now(),
        ),
      );
    }

    // Observations + unsafe observations.
    final oldToNewObservationId = <int, int>{};

    Future<void> importObservation(
      Map<String, dynamic> o, {
      required bool isUnsafe,
    }) async {
      final questionReference = _readString(o, 'questionReference');
      if (questionReference.isEmpty) return;

      final oldId = _tryParseInt(o['id']);
      final newId = await db.saveObservation(
        formId: newFormId,
        questionReference: questionReference,
        notes: _readNullableString(o, 'notes'),
        imagePaths: _asStringList(o['imagePaths']),
        questionText: _readNullableString(o, 'questionText'),
        sectionName: _readNullableString(o, 'sectionName'),
        assetId: _tryParseInt(o['assetId']),
        assetType: _readNullableString(o, 'assetType'),
        assetMakeModel: _readNullableString(o, 'assetMakeModel'),
        isUnsafe: isUnsafe,
        unsafeClassification: _readNullableString(o, 'unsafeClassification'),
        unsafeActionTaken: _readNullableString(o, 'unsafeActionTaken'),
        unsafeWarningNoticeImage: _readNullableString(
          o,
          'unsafeWarningNoticeImage',
        ),
        unsafeAfterImage: _readNullableString(o, 'unsafeAfterImage'),
        unsafeResidentReaction: _readNullableString(
          o,
          'unsafeResidentReaction',
        ),
        unsafeReportedToClient: _readNullableString(
          o,
          'unsafeReportedToClient',
        ),
        unsafeReportedInternally: _readNullableString(
          o,
          'unsafeReportedInternally',
        ),
        unsafeCheckedBy: _readNullableString(o, 'unsafeCheckedBy'),
        unsafeCheckedDate: _readNullableString(o, 'unsafeCheckedDate'),
        unsafeSentVia: _readNullableString(o, 'unsafeSentVia'),
        unsafeSentTo: _readNullableString(o, 'unsafeSentTo'),
      );

      if (oldId != null) {
        oldToNewObservationId[oldId] = newId;
      }
    }

    final observations = _asListOfMaps(hna['observations']);
    for (final o in observations) {
      await importObservation(o, isUnsafe: false);
    }

    final unsafe = _asMap(hna['unsafe']);
    final unsafeObs = _asListOfMaps(unsafe['unsafeObservations']);
    for (final o in unsafeObs) {
      await importObservation(o, isUnsafe: true);
    }

    // Unsafe reports (remap observation ids).
    final unsafeReports = _asListOfMaps(unsafe['unsafeReports']);
    for (final r in unsafeReports) {
      final obsIds = (r['observationIds'] is List)
          ? (r['observationIds'] as List)
                .map(_tryParseInt)
                .whereType<int>()
                .toList()
          : const <int>[];

      final mapped = obsIds
          .map((oldId) => oldToNewObservationId[oldId])
          .whereType<int>()
          .toList();

      await db.saveUnsafeReport(
        formId: newFormId,
        actionTaken: _readNullableString(r, 'actionTaken'),
        warningNoticeImage: _readNullableString(r, 'warningNoticeImage'),
        afterImage: _readNullableString(r, 'afterImage'),
        reportedToClient: _readNullableString(r, 'reportedToClient'),
        reportedInternally: _readNullableString(r, 'reportedInternally'),
        observationIds: mapped,
      );
    }

    ApmLogger.info(
      'Hydrated edit-session snapshot to local form formId=$newFormId submissionId=$submissionId editRequestId=$editRequestId',
      category: 'HNA/EditHydrate',
    );

    return newFormId;
  }
}
