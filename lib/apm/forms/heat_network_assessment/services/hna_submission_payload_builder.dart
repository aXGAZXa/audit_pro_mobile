import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_derived_metrics_calculator.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_pdf_derived_calculator.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_pdf_model_builder.dart';
import 'package:audit_pro_mobile/apm/models/communal_control.dart';
import 'package:audit_pro_mobile/apm/models/dhw_plant.dart';
import 'package:audit_pro_mobile/apm/models/dwelling_inspection.dart';
import 'package:audit_pro_mobile/apm/models/heat_generator.dart';
import 'package:audit_pro_mobile/apm/models/heat_meter.dart';
import 'package:audit_pro_mobile/apm/models/plate_heat_exchanger.dart';

class HnaSubmissionPayloadBuilder {
  static const int payloadSchemaVersion = 4;

  static String buildFriendlyRef({
    required DateTime submittedAt,
    required String formUuid,
  }) {
    return _buildFriendlyRef(submittedAt: submittedAt, formUuid: formUuid);
  }

  static Future<Map<String, dynamic>?> build({
    required int formId,
    DatabaseHelper? db,
    DateTime? submittedAt,
    bool computeDerivedIfMissing = true,
    bool recomputeDerived = false,
    String methodologyVersion = 'v1',
  }) async {
    final database = db ?? DatabaseHelper.instance;
    final submitTimestamp = submittedAt ?? DateTime.now();

    final form = await database.getForm(formId);
    if (form == null) return null;

    final formData = Map<String, dynamic>.from(form['form_data'] as Map);

    final shouldComputeDerivedMetrics =
        recomputeDerived ||
        (computeDerivedIfMissing && formData['derivedMetrics'] == null);
    if (shouldComputeDerivedMetrics) {
      formData['derivedMetrics'] = await HnaDerivedMetricsCalculator.compute(
        formId: formId,
        formData: formData,
        db: database,
        methodologyVersion: methodologyVersion,
      );
    }

    final meters = await database.getHeatMeters(formId);
    final generators = await database.getHeatGenerators(formId);
    final phex = await database.getPlateHeatExchangers(formId);
    final dhwPlants = await database.getDhwPlants(formId);
    final communalControls = await database.getCommunalControls(formId);
    final dwellingInspections = await database.getDwellingInspections(formId);

    // App-prepared PDF-derived fields (triage + metering narrative). Portal uses these when present.
    final shouldComputePdfDerived =
        recomputeDerived ||
        (computeDerivedIfMissing && formData['pdfDerived'] == null);
    if (shouldComputePdfDerived) {
      formData['pdfDerived'] = HnaPdfDerivedCalculator.compute(
        formData: formData,
        meters: meters,
        generators: generators,
        phex: phex,
        dhwPlants: dhwPlants,
        communalControls: communalControls,
        dwellingInspections: dwellingInspections,
        methodologyVersion: methodologyVersion,
      );
    }

    final observations = await database.getFormObservations(formId);
    final unsafeObservations = await database.getUnsafeObservations(formId);
    final unsafeReports = await database.getUnsafeReports(formId);
    final unreportedUnsafe = await database.getUnreportedUnsafeObservations(
      formId,
    );

    final assetsJson = {
      'heatMeters': meters.map(_heatMeterToJson).toList(),
      'plateHeatExchangers': phex.map(_phexToJson).toList(),
      'heatGenerators': generators.map(_heatGeneratorToJson).toList(),
      'dhwPlants': dhwPlants.map(_dhwPlantToJson).toList(),
      'communalControls': communalControls.map(_communalControlToJson).toList(),
      'dwellingInspections': dwellingInspections
          .map(_dwellingInspectionToJson)
          .toList(),
    };

    final observationsJson = observations.map(_observationToJson).toList();
    final unsafeObservationsJson = unsafeObservations
        .map(_observationToJson)
        .toList();
    final unreportedUnsafeJson = unreportedUnsafe
        .map(_observationToJson)
        .toList();
    final unsafeReportsJson = unsafeReports.map(_unsafeReportToJson).toList();

    final attachments = _collectAttachments(
      formId: formId,
      formData: formData,
      assetsJson: assetsJson,
      observationsJson: observationsJson,
      unsafeObservationsJson: unsafeObservationsJson,
      unsafeReportsJson: unsafeReportsJson,
      unreportedUnsafeObservationsJson: unreportedUnsafeJson,
    );

    final formUuid = (form['uuid'] ?? '').toString();
    final friendlyRef = _buildFriendlyRef(
      submittedAt: submitTimestamp,
      formUuid: formUuid,
    );

    final pdfModel = HnaPdfModelBuilder.build(
      formId: formId,
      reportNumber: friendlyRef,
      formData: formData,
      assetsJson: assetsJson,
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
      'formUuid': formUuid,
      // Local device identifier (kept for back-compat / debugging).
      'formId': formId,
    };

    return {
      'payloadSchemaVersion': payloadSchemaVersion,
      'form': {
        'id': form['id'],
        'uuid': form['uuid'],
        'formType': form['form_type'],
        'status': form['status'],
        'createdAt': form['created_at'],
        'updatedAt': form['updated_at'],
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
          localPaths: o['imagePaths'] as List?,
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

  static Map<String, dynamic> _heatMeterToJson(HeatMeter m) => {
    'id': m.id,
    'meterType': m.meterType,
    'make': m.make,
    'model': m.model,
    'location': m.location,
    'ageRange': m.ageRange,
    'serialNumber': m.serialNumber,
    'operational': m.operational,
    'reading': m.reading,
    'relatedAssetType': m.relatedAssetType,
    'relatedAssetId': m.relatedAssetId,
    'imagePaths': m.imagePaths,
    'createdAt': m.createdAt.toIso8601String(),
    'updatedAt': m.updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> _phexToJson(PlateHeatExchanger p) => {
    'id': p.id,
    'location': p.location,
    'make': p.make,
    'model': p.model,
    'serialNumber': p.serialNumber,
    'capacity': p.capacity,
    'ageRange': p.ageRange,
    'condition': p.condition,
    'insulationCondition': p.insulationCondition,
    'freeOfLeaks': p.freeOfLeaks,
    'hasIsolationValves': p.hasIsolationValves,
    'hasTempGauges': p.hasTempGauges,
    'hasIndividualMeter': p.hasIndividualMeter,
    'imagePaths': p.imagePaths,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> _heatGeneratorToJson(HeatGenerator g) => {
    'id': g.id,
    'generatorType': g.generatorType,
    'fuelType': g.fuelType,
    'location': g.location,
    'make': g.make,
    'model': g.model,
    'serialNumber': g.serialNumber,
    'capacity': g.capacity,
    'ageRange': g.ageRange,
    'condition': g.condition,
    'operational': g.operational,
    'hasIndividualMeter': g.hasIndividualMeter,
    'imagePaths': g.imagePaths,
    'createdAt': g.createdAt.toIso8601String(),
    'updatedAt': g.updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> _dhwPlantToJson(DhwPlant p) => {
    'id': p.id,
    'plantType': p.plantType,
    'fuelType': p.fuelType,
    'location': p.location,
    'make': p.make,
    'model': p.model,
    'serialNumber': p.serialNumber,
    'capacity': p.capacity,
    'heatInput': p.heatInput,
    'ageRange': p.ageRange,
    'condition': p.condition,
    'operational': p.operational,
    'imagePaths': p.imagePaths,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> _communalControlToJson(CommunalControl c) => {
    'id': c.id,
    'controlType': c.controlType,
    'location': c.location,
    'make': c.make,
    'model': c.model,
    'serialNumber': c.serialNumber,
    'condition': c.condition,
    'operational': c.operational,
    'imagePaths': c.imagePaths,
    'createdAt': c.createdAt.toIso8601String(),
    'updatedAt': c.updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> _dwellingInspectionToJson(DwellingInspection d) =>
      {
        'id': d.id,
        'location': d.location,
        'heatingType': d.heatingType,
        'heatGeneratorType': d.heatGeneratorType,
        'heatGeneratorFuelType': d.heatGeneratorFuelType,
        'heatDistributionType': d.heatDistributionType,
        'dhwType': d.dhwType,
        'dhwGeneratorType': d.dhwGeneratorType,
        'dhwGeneratorFuelType': d.dhwGeneratorFuelType,
        'dhwCommunalType': d.dhwCommunalType,
        'heatingControls': d.heatingControls,
        'heatingControlsOther': d.heatingControlsOther,
        'heatingNotes': d.heatingNotes,
        'heatingImagePaths': d.heatingImagePaths,
        'dhwControls': d.dhwControls,
        'dhwControlsOther': d.dhwControlsOther,
        'dhwNotes': d.dhwNotes,
        'dhwImagePaths': d.dhwImagePaths,
        'heatingMetered': d.heatingMetered,
        'heatingSubMeterFeasible': d.heatingSubMeterFeasible,
        'heatingSubMeterFeasibilityReason': d.heatingSubMeterFeasibilityReason,
        'heatingSubMeterEvidenceImages': d.heatingSubMeterEvidenceImages,
        'dhwMetered': d.dhwMetered,
        'dhwSubMeterFeasible': d.dhwSubMeterFeasible,
        'dhwSubMeterFeasibilityReason': d.dhwSubMeterFeasibilityReason,
        'dhwSubMeterEvidenceImages': d.dhwSubMeterEvidenceImages,
        'hiuMake': d.hiuMake,
        'hiuModel': d.hiuModel,
        'hiuSerialNumber': d.hiuSerialNumber,
        'condition': d.condition,
        'operational': d.operational,
        'imagePaths': d.imagePaths,
        'createdAt': d.createdAt?.toIso8601String(),
        'updatedAt': d.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _observationToJson(Map<String, dynamic> o) {
    final assetId = o['asset_id'];
    final assetType = o['asset_type'];
    final assetMakeModel = o['asset_make_model'];

    return {
      'id': o['id'],
      // Generic attachment model: observations attach to a question by default.
      // (HNA is not a plant room inspection, so we intentionally avoid exporting
      // plant-room-specific identifiers.)
      'attachedTo': {
        'type': 'question',
        'questionReference': o['question_reference'],
        'questionText': o['question_text'],
        'sectionName': o['section_name'],
      },
      // Keep existing flat fields for backward compatibility.
      'questionReference': o['question_reference'],
      'questionText': o['question_text'],
      'sectionName': o['section_name'],
      'notes': o['notes'],
      'assetId': assetId,
      'assetType': assetType,
      'assetMakeModel': assetMakeModel,
      if (assetId != null || assetType != null || assetMakeModel != null)
        'asset': {
          'id': assetId,
          'type': assetType,
          'makeModel': assetMakeModel,
        },
      'isUnsafe': (o['is_unsafe'] == 1),
      'unsafeClassification': o['unsafe_classification'],
      'unsafeActionTaken': o['unsafe_action_taken'],
      'unsafeWarningNoticeImage': o['unsafe_warning_notice_image'],
      'unsafeAfterImage': o['unsafe_after_image'],
      'unsafeResidentReaction': o['unsafe_resident_reaction'],
      'unsafeReportedToClient': o['unsafe_reported_to_client'],
      'unsafeReportedInternally': o['unsafe_reported_internally'],
      'unsafeCheckedBy': o['unsafe_checked_by'],
      'unsafeCheckedDate': o['unsafe_checked_date'],
      'unsafeSentVia': o['unsafe_sent_via'],
      'unsafeSentTo': o['unsafe_sent_to'],
      'createdAt': o['created_at'],
      'updatedAt': o['updated_at'],
      'imagePaths': (o['images'] as List?) ?? const [],
    };
  }

  static Map<String, dynamic> _unsafeReportToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'actionTaken': r['action_taken'],
    'warningNoticeImage': r['warning_notice_image'],
    'afterImage': r['after_image'],
    'reportedToClient': r['reported_to_client'],
    'reportedInternally': r['reported_internally'],
    'observationIds': r['observation_ids'],
    'observationCount': r['observation_count'],
    'createdAt': r['created_at'],
    'updatedAt': r['updated_at'],
  };
}
