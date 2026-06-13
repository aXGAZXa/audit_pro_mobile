// App-vs-web convergence cross-check (Phase 2b gate).
//
// The Condition Report has two serialization paths:
//   - APP: CrSubmissionPayloadBuilder.build(formId, db)        — reads the SQLite tables
//   - WEB: CrSubmissionPayloadBuilder.buildFromFormSnapshot(..) — reads an in-memory snapshot
//
// The client I/O refactor converges CR onto the snapshot/blob model. This test
// proves that, fed the SAME collections, the two paths produce the IDENTICAL
// `conditionReport` envelope — i.e. converging is payload-safe. It is the hard
// guardrail required before the screen surgery.
import 'dart:convert';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/condition_report_definition.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('CR app build() and web buildFromFormSnapshot() converge', () async {
    final db = DatabaseHelper.instance;

    final formId = await db.saveForm(
      formType: kConditionReportFormType,
      status: 'draft',
      formData: <String, dynamic>{
        'client': 'Acme Housing',
        'siteName': 'Riverside Court',
        'auditorName': 'Jane Assessor',
        'auditDate': '2025-12-10',
      },
    );

    await db.saveAsset(
      formId: formId,
      assetTypeId: 1,
      assetMake: 'Bosch',
      assetModel: 'GB162',
      location: 'Plant Room A',
      operational: 'yes',
      visualCondition: 'good',
      imagePaths: <String>['asset_1_front.jpg'],
    );
    await db.savePlantRoom(
      formId: formId,
      location: 'Basement',
      accessImagePaths: <String>['plantroom_1_access.jpg'],
      internalImagePaths: const <String>[],
    );
    await db.saveObservation(
      formId: formId,
      questionReference: 'CR.SITE.01',
      notes: 'Minor corrosion on flow pipe.',
      imagePaths: <String>['obs_1_a.jpg', 'obs_1_b.jpg'],
    );

    final at = DateTime.utc(2026, 1, 1, 12, 0, 0);

    // APP path: serialize straight from the SQLite tables.
    final appPayload =
        await CrSubmissionPayloadBuilder.build(formId: formId, db: db, submittedAt: at);
    expect(appPayload, isNotNull);
    final appCr = Map<String, dynamic>.from(
      appPayload!['conditionReport'] as Map,
    );

    // WEB path: assemble the same raw collections into the snapshot the repo
    // would hold, then serialize via the snapshot builder.
    final form = await db.getForm(formId);
    final formData = Map<String, dynamic>.from(form!['form_data'] as Map);
    final snapshot = <String, dynamic>{
      ...formData,
      'assets': await db.getAssets(formId),
      'plantRooms': await db.getPlantRooms(formId),
      'observations': await db.getFormObservations(formId),
      'unsafe': {
        'unsafeObservations': await db.getUnsafeObservations(formId),
        'unsafeReports': await db.getUnsafeReports(formId),
      },
    };
    final webPayload = CrSubmissionPayloadBuilder.buildFromFormSnapshot(
      formSnapshot: snapshot,
      formId: formId,
      submittedAt: at,
    );
    final webCr = Map<String, dynamic>.from(
      webPayload['conditionReport'] as Map,
    );

    expect(
      _canonicalJson(webCr),
      _canonicalJson(appCr),
      reason: 'CR web serialization diverges from the app for the same '
          'collections — converging to the blob model would NOT be payload-safe. '
          'Resolve the divergence before the screen surgery.',
    );
  });
}

String _canonicalJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_sortDeep(value));

Object? _sortDeep(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sortDeep(value[k])};
  }
  if (value is List) return value.map(_sortDeep).toList();
  return value;
}
