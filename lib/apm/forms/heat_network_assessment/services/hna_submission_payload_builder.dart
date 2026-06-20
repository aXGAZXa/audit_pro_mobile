import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_derived_metrics_calculator.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_pdf_derived_calculator.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_pdf_model_builder.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HnaSubmissionPayloadBuilder {
  static const int payloadSchemaVersion = 4;

  static const String _formDataKey = 'formData';
  static const String _assetsKey = 'assets';
  static const String _submissionSummaryKey = 'submissionSummary';
  static const String _editSessionKey = 'editSession';

  static String buildFriendlyRef({
    required DateTime submittedAt,
    required String formUuid,
  }) {
    return _buildFriendlyRef(submittedAt: submittedAt, formUuid: formUuid);
  }

  /// Build the v4 submission envelope for a STORED form (mobile path): load the
  /// form row + its `form_data` document, then delegate to [buildFromFormSnapshot].
  /// Thin wrapper so the load and the envelope assembly are the SAME code the
  /// snapshot path uses (guarded by the v4 golden + the mobile equivalence gate).
  static Future<Map<String, dynamic>?> build({
    required int formId,
    DatabaseHelper? db,
    DateTime? submittedAt,
    bool computeDerivedIfMissing = true,
    bool recomputeDerived = false,
    String methodologyVersion = 'v1',
  }) async {
    final database = db ?? DatabaseHelper.instance;

    final form = await database.getForm(formId);
    if (form == null) return null;

    return buildFromFormSnapshot(
      formSnapshot: Map<String, dynamic>.from(form['form_data'] as Map),
      formId: form['id'] is int ? form['id'] as int : formId,
      formUuid: form['uuid'],
      formType: form['form_type'],
      status: form['status'],
      createdAt: form['created_at'],
      updatedAt: form['updated_at'],
      submittedAt: submittedAt,
      computeDerivedIfMissing: computeDerivedIfMissing,
      recomputeDerived: recomputeDerived,
      methodologyVersion: methodologyVersion,
    );
  }

  /// Assemble the v4 envelope from an in-memory HNA document (the `form_data`
  /// blob — `repo.formData` on mobile, the `payload['hna']`-derived snapshot on
  /// web). The single serialization core both platforms converge on (mirrors
  /// CR's buildFromFormSnapshot). Form-row metadata (id/uuid/status/timestamps)
  /// is passed in since it lives outside the document. `formUuid` is the RAW row
  /// value (may be null) — the form section keeps it raw; friendlyRef + summary
  /// use the stringified form, exactly as the original build() did.
  static Future<Map<String, dynamic>> buildFromFormSnapshot({
    required Map<String, dynamic> formSnapshot,
    required int formId,
    Object? formUuid,
    Object? formType,
    Object? status,
    Object? createdAt,
    Object? updatedAt,
    DateTime? submittedAt,
    bool computeDerivedIfMissing = true,
    bool recomputeDerived = false,
    String methodologyVersion = 'v1',
    // Web editor supplies the attachment manifest from
    // FormWebEditorAttachmentContext.buildManifest, which PRESERVES the server's
    // existing att-ids (so previously-uploaded blobs still resolve for the PDF)
    // and carries upload metadata. Mobile leaves this null and path-walks.
    List<Map<String, dynamic>>? attachmentsOverride,
  }) async {
    final submitTimestamp = submittedAt ?? DateTime.now();

    final draftDoc = formSnapshot;
    final formData = _readFormDataFromDraft(draftDoc);
    final assetsJson = _readAssetsFromDraft(draftDoc) ?? <String, dynamic>{};
    _ensureAssetsShape(assetsJson);

    final observationsJson = _asListOfMaps(draftDoc['observations']);

    final unsafeJson =
        _asMapStringDynamic(draftDoc['unsafe']) ??
        <String, dynamic>{
          'unsafeObservations': <Map<String, dynamic>>[],
          'unsafeReports': <Map<String, dynamic>>[],
          'unreportedUnsafeObservations': <Map<String, dynamic>>[],
        };

    final unsafeObservationsJson = _asListOfMaps(
      unsafeJson['unsafeObservations'],
    );
    final unsafeReportsJson = _asListOfMaps(unsafeJson['unsafeReports']);
    final unreportedUnsafeJson = _asListOfMaps(
      unsafeJson['unreportedUnsafeObservations'],
    );

    final shouldComputeDerivedMetrics =
        recomputeDerived ||
        (computeDerivedIfMissing && formData['derivedMetrics'] == null);
    if (shouldComputeDerivedMetrics) {
      formData['derivedMetrics'] =
          HnaDerivedMetricsCalculator.computeFromPayload(
            formData: formData,
            assetsJson: assetsJson,
            observationsJson: observationsJson,
            unsafeJson: unsafeJson,
            methodologyVersion: methodologyVersion,
          );
    }

    // App-prepared PDF-derived fields (triage + metering narrative). Portal uses these when present.
    final shouldComputePdfDerived =
        recomputeDerived ||
        (computeDerivedIfMissing && formData['pdfDerived'] == null);
    if (shouldComputePdfDerived) {
      formData['pdfDerived'] = HnaPdfDerivedCalculator.computeFromPayload(
        formData: formData,
        assetsJson: assetsJson,
        observationsJson: observationsJson,
        methodologyVersion: methodologyVersion,
      );
    }

    // Reduce cross-device friction: normalize any file paths under the app's
    // documents directory to just the file name before building attachments.
    // This avoids storing device-specific absolute paths in the payload JSON.
    await _normalizeAppDocumentFileRefsInPlace(
      formData: formData,
      assetsJson: assetsJson,
      observationsJson: observationsJson,
      unsafeObservationsJson: unsafeObservationsJson,
      unsafeReportsJson: unsafeReportsJson,
      unreportedUnsafeObservationsJson: unreportedUnsafeJson,
    );

    final attachments =
        attachmentsOverride ??
        _collectAttachments(
          formId: formId,
          formData: formData,
          assetsJson: assetsJson,
          observationsJson: observationsJson,
          unsafeObservationsJson: unsafeObservationsJson,
          unsafeReportsJson: unsafeReportsJson,
          unreportedUnsafeObservationsJson: unreportedUnsafeJson,
        );

    final formUuidStr = (formUuid ?? '').toString();
    final friendlyRef = _buildFriendlyRef(
      submittedAt: submitTimestamp,
      formUuid: formUuidStr,
    );

    final pdfModel = HnaPdfModelBuilder.build(
      formId: formId,
      reportNumber: friendlyRef,
      formData: formData,
      assetsJson: assetsJson,
      observationsJson: observationsJson,
      unsafeObservationsJson: unsafeObservationsJson,
      unsafeReportsJson: unsafeReportsJson,
      attachments: attachments,
    );

    final formDataClient = (formData['client'] ?? '').toString();
    final formDataAssessor = (formData['auditorName'] ?? '').toString();

    final summary = {
      'assessorName': formDataAssessor,
      'clientName': formDataClient,
      'auditDate': (formData['auditDate'] ?? '').toString(),
      'submittedAt': submitTimestamp.toIso8601String(),
      'friendlyRef': friendlyRef,
      // Cross-device stable identifier (preferred over the local autoincrement id).
      'formUuid': formUuidStr,
      // Local device identifier (kept for back-compat / debugging).
      'formId': formId,
    };

    return {
      'payloadSchemaVersion': payloadSchemaVersion,
      'form': {
        'id': formId,
        'uuid': formUuid,
        'formType': formType,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      },
      'hna': {
        'summary': summary,
        'formData': formData,
        'assets': assetsJson,
        'observations': observationsJson,
        'pdfModel': pdfModel,
        'attachments': attachments,
        'unsafe': {
          'unsafeObservations': unsafeObservationsJson,
          'unsafeReports': unsafeReportsJson,
          'unreportedUnsafeObservations': unreportedUnsafeJson,
        },
      },
    };
  }

  static String _buildFriendlyRef({
    required DateTime submittedAt,
    required String formUuid,
  }) {
    final yy = (submittedAt.year % 100).toString().padLeft(2, '0');
    final mm = submittedAt.month.toString().padLeft(2, '0');
    final dd = submittedAt.day.toString().padLeft(2, '0');
    final hh = submittedAt.hour.toString().padLeft(2, '0');
    final min = submittedAt.minute.toString().padLeft(2, '0');

    final suffix = _uuidSuffix(formUuid);

    // Format: HNA-yyMMdd-HHmm-XXX (e.g. HNA-260225-2122-A1B)
    return 'HNA-$yy$mm$dd-$hh$min-$suffix';
  }

  static String _uuidSuffix(String uuid) {
    final cleaned = uuid.replaceAll('-', '').trim();
    if (cleaned.length < 3) return 'XXX';
    return cleaned.substring(0, 3).toUpperCase();
  }

  static Map<String, dynamic> _readFormDataFromDraft(
    Map<String, dynamic> draftDoc,
  ) {
    final raw = draftDoc[_formDataKey];
    if (raw is Map) return Map<String, dynamic>.from(raw);

    // Legacy draft shape: form fields at the root.
    // Keep submission metadata at the root and exclude assets.
    final copy = Map<String, dynamic>.from(draftDoc);
    copy.remove(_submissionSummaryKey);
    copy.remove(_editSessionKey);
    copy.remove(_assetsKey);
    return copy;
  }

  static Map<String, dynamic>? _readAssetsFromDraft(
    Map<String, dynamic> draftDoc,
  ) {
    final raw = draftDoc[_assetsKey];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Map<String, dynamic>? _asMapStringDynamic(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );
    }
    return null;
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is List<Map<String, dynamic>>) return value;
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  static void _ensureAssetsShape(Map<String, dynamic> assetsJson) {
    const expectedListKeys = <String>[
      'heatMeters',
      'plateHeatExchangers',
      'heatGenerators',
      'dhwPlants',
      'communalControls',
      'dwellingInspections',
    ];

    for (final k in expectedListKeys) {
      assetsJson[k] = _asListOfMaps(assetsJson[k]);
    }
  }

  static List<Map<String, dynamic>> _collectAttachments({
    required int formId,
    required Map<String, dynamic> formData,
    required Map<String, dynamic> assetsJson,
    required List<Map<String, dynamic>> observationsJson,
    required List<Map<String, dynamic>> unsafeObservationsJson,
    required List<Map<String, dynamic>> unsafeReportsJson,
    required List<Map<String, dynamic>> unreportedUnsafeObservationsJson,
  }) {
    final byPath = <String, Map<String, dynamic>>{};

    void addLink({
      required String localPath,
      required String ownerType,
      required dynamic ownerId,
      required String field,
      required String role,
    }) {
      final trimmed = localPath.trim();
      if (trimmed.isEmpty) return;

      final entry = byPath.putIfAbsent(trimmed, () {
        return {
          'localPath': trimmed,
          'contentType': _inferContentType(trimmed),
          'links': <Map<String, dynamic>>[],
        };
      });

      (entry['links'] as List).add({
        'ownerType': ownerType,
        'ownerId': ownerId,
        'field': field,
        'role': role,
      });
    }

    void addLinksFromList({
      required List<dynamic>? localPaths,
      required String ownerType,
      required dynamic ownerId,
      required String field,
      required String role,
    }) {
      if (localPaths == null) return;
      for (final p in localPaths) {
        if (p == null) continue;
        addLink(
          localPath: p.toString(),
          ownerType: ownerType,
          ownerId: ownerId,
          field: field,
          role: role,
        );
      }
    }

    // Signatures (stored in formData)
    final siteRepSig = formData['siteRepSignature']?.toString();
    if (siteRepSig != null && siteRepSig.trim().isNotEmpty) {
      addLink(
        localPath: siteRepSig,
        ownerType: 'form',
        ownerId: formId,
        field: 'siteRepSignature',
        role: 'signature_site_rep',
      );
    }
    final auditorSig = formData['auditorSignature']?.toString();
    if (auditorSig != null && auditorSig.trim().isNotEmpty) {
      addLink(
        localPath: auditorSig,
        ownerType: 'form',
        ownerId: formId,
        field: 'auditorSignature',
        role: 'signature_auditor',
      );
    }

    // Asset photos
    for (final m in (assetsJson['heatMeters'] as List? ?? const [])) {
      addLinksFromList(
        localPaths: (m as Map<String, dynamic>)['imagePaths'] as List?,
        ownerType: 'heat_meter',
        ownerId: m['id'],
        field: 'imagePaths',
        role: 'photo',
      );
    }

    for (final x in (assetsJson['plateHeatExchangers'] as List? ?? const [])) {
      addLinksFromList(
        localPaths: (x as Map<String, dynamic>)['imagePaths'] as List?,
        ownerType: 'plate_heat_exchanger',
        ownerId: x['id'],
        field: 'imagePaths',
        role: 'photo',
      );
    }

    for (final g in (assetsJson['heatGenerators'] as List? ?? const [])) {
      addLinksFromList(
        localPaths: (g as Map<String, dynamic>)['imagePaths'] as List?,
        ownerType: 'heat_generator',
        ownerId: g['id'],
        field: 'imagePaths',
        role: 'photo',
      );
    }

    for (final p in (assetsJson['dhwPlants'] as List? ?? const [])) {
      addLinksFromList(
        localPaths: (p as Map<String, dynamic>)['imagePaths'] as List?,
        ownerType: 'dhw_plant',
        ownerId: p['id'],
        field: 'imagePaths',
        role: 'photo',
      );
    }

    for (final c in (assetsJson['communalControls'] as List? ?? const [])) {
      addLinksFromList(
        localPaths: (c as Map<String, dynamic>)['imagePaths'] as List?,
        ownerType: 'communal_control',
        ownerId: c['id'],
        field: 'imagePaths',
        role: 'photo',
      );
    }

    for (final d in (assetsJson['dwellingInspections'] as List? ?? const [])) {
      final di = d as Map<String, dynamic>;
      addLinksFromList(
        localPaths: di['imagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: di['id'],
        field: 'imagePaths',
        role: 'photo',
      );
      addLinksFromList(
        localPaths: di['heatingImagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: di['id'],
        field: 'heatingImagePaths',
        role: 'photo_heating',
      );
      addLinksFromList(
        localPaths: di['dhwImagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: di['id'],
        field: 'dhwImagePaths',
        role: 'photo_dhw',
      );
      addLinksFromList(
        localPaths: di['heatingSubMeterEvidenceImages'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: di['id'],
        field: 'heatingSubMeterEvidenceImages',
        role: 'evidence_heating_submeter',
      );
      addLinksFromList(
        localPaths: di['dhwSubMeterEvidenceImages'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: di['id'],
        field: 'dhwSubMeterEvidenceImages',
        role: 'evidence_dhw_submeter',
      );
    }

    void collectFromObservationList(
      List<Map<String, dynamic>> list, {
      required String listRole,
    }) {
      for (final o in list) {
        final obsId = o['id'];

        addLinksFromList(
          localPaths: (o['imagePaths'] ?? o['images']) as List?,
          ownerType: 'observation',
          ownerId: obsId,
          field: 'imagePaths',
          role: 'photo_$listRole',
        );

        final notice = o['unsafeWarningNoticeImage']?.toString();
        if (notice != null && notice.trim().isNotEmpty) {
          addLink(
            localPath: notice,
            ownerType: 'observation',
            ownerId: obsId,
            field: 'unsafeWarningNoticeImage',
            role: 'unsafe_warning_notice_$listRole',
          );
        }

        final after = o['unsafeAfterImage']?.toString();
        if (after != null && after.trim().isNotEmpty) {
          addLink(
            localPath: after,
            ownerType: 'observation',
            ownerId: obsId,
            field: 'unsafeAfterImage',
            role: 'unsafe_after_$listRole',
          );
        }
      }
    }

    collectFromObservationList(observationsJson, listRole: 'general');
    collectFromObservationList(unsafeObservationsJson, listRole: 'unsafe');
    collectFromObservationList(
      unreportedUnsafeObservationsJson,
      listRole: 'unsafe_unreported',
    );

    // Unsafe report images (these can be different from per-observation images)
    for (final r in unsafeReportsJson) {
      final reportId = r['id'];
      final warning = r['warningNoticeImage']?.toString();
      if (warning != null && warning.trim().isNotEmpty) {
        addLink(
          localPath: warning,
          ownerType: 'unsafe_report',
          ownerId: reportId,
          field: 'warningNoticeImage',
          role: 'unsafe_report_warning_notice',
        );
      }
      final after = r['afterImage']?.toString();
      if (after != null && after.trim().isNotEmpty) {
        addLink(
          localPath: after,
          ownerType: 'unsafe_report',
          ownerId: reportId,
          field: 'afterImage',
          role: 'unsafe_report_after',
        );
      }
    }

    final entries = byPath.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final attachments = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length; i++) {
      attachments.add({
        'id': 'att_${(i + 1).toString().padLeft(4, '0')}',
        ...entries[i].value,
      });
    }

    return attachments;
  }

  static String? _inferContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return null;
  }

  static Future<void> _normalizeAppDocumentFileRefsInPlace({
    required Map<String, dynamic> formData,
    required Map<String, dynamic> assetsJson,
    required List<Map<String, dynamic>> observationsJson,
    required List<Map<String, dynamic>> unsafeObservationsJson,
    required List<Map<String, dynamic>> unsafeReportsJson,
    required List<Map<String, dynamic>> unreportedUnsafeObservationsJson,
  }) async {
    if (kIsWeb) return;

    String appDirPath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      appDirPath = appDir.path;
    } catch (_) {
      return;
    }

    if (appDirPath.trim().isEmpty) return;

    // Normalize separators so startsWith checks are consistent.
    final normalizedAppDir = p.normalize(appDirPath).replaceAll('\\', '/');

    dynamic normalizeNode(dynamic node) {
      if (node == null) return null;

      if (node is String) {
        final trimmed = node.trim();
        if (trimmed.isEmpty) return node;

        // Leave URLs and data/blob URIs alone.
        if (trimmed.contains('://') || trimmed.startsWith('data:')) return node;

        final normalized = p.normalize(trimmed).replaceAll('\\', '/');
        if (normalized.startsWith('$normalizedAppDir/')) {
          return p.basename(normalized);
        }

        return node;
      }

      if (node is List) {
        for (var i = 0; i < node.length; i++) {
          node[i] = normalizeNode(node[i]);
        }
        return node;
      }

      if (node is Map) {
        final keys = node.keys.toList();
        for (final k in keys) {
          node[k] = normalizeNode(node[k]);
        }
        return node;
      }

      return node;
    }

    normalizeNode(formData);
    normalizeNode(assetsJson);
    normalizeNode(observationsJson);
    normalizeNode(unsafeObservationsJson);
    normalizeNode(unsafeReportsJson);
    normalizeNode(unreportedUnsafeObservationsJson);
  }
}
