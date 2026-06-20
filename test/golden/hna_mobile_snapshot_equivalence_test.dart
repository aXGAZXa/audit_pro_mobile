// Keystone proof for the HNA mobile-submit convergence (mirrors the CR one).
//
// HNA submit will switch from `build(formId, db)` to
// `buildFromFormSnapshot(repo.formData, ...)` — the same core the web editor
// will converge on. This test proves that assembling the v4 envelope from a
// SqliteFormRepository-loaded document is byte-identical (modulo volatile
// timestamps) to the current `build(formId)` path, so the live submit can switch
// safely. If it ever fails, the repo snapshot diverged from the stored blob and
// must be reconciled BEFORE touching the live HNA submit path.
import 'dart:convert';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_payload_builder.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/sqlite_form_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('HNA build() == buildFromFormSnapshot(repo.formData) (keystone)', () async {
    final db = DatabaseHelper.instance;

    final formId = await db.saveForm(
      formType: kHeatNetworkAssessmentFormType,
      status: 'draft',
      uuid: 'hna-uuid-fixed-eq01',
      formData: _representativeHnaDraft(),
    );

    final at = DateTime.utc(2026, 1, 1, 12, 0, 0);

    // Current live path: straight from the stored form (build loads + assembles).
    final appPayload = await HnaSubmissionPayloadBuilder.build(
      formId: formId,
      db: db,
      submittedAt: at,
    );
    expect(appPayload, isNotNull);

    // Target path: load the document via the repo and assemble from the snapshot,
    // exactly as production mobile submit will.
    final form = await db.getForm(formId);
    final repo = SqliteFormRepository(db: db);
    await repo.loadOrCreateDraft(
      formType: kHeatNetworkAssessmentFormType,
      explicitFormId: formId,
    );
    final snapshotPayload = await HnaSubmissionPayloadBuilder.buildFromFormSnapshot(
      formSnapshot: repo.formData,
      formId: form!['id'] as int,
      formUuid: form['uuid'],
      formType: form['form_type'],
      status: form['status'],
      createdAt: form['created_at'],
      updatedAt: form['updated_at'],
      submittedAt: at,
    );

    expect(
      _canonicalJson(_normalizeVolatile(snapshotPayload)),
      _canonicalJson(_normalizeVolatile(appPayload!)),
      reason:
          'HNA snapshot assembled from repo.formData must equal build() so mobile '
          'submit can switch to buildFromFormSnapshot(repo.formData) safely.',
    );
  });
}

Map<String, dynamic> _representativeHnaDraft() => {
  'formData': {
    'client': 'Acme Housing',
    'siteName': 'Riverside Court',
    'auditorName': 'Jane Assessor',
    'auditDate': '2025-12-10',
  },
  'assets': {
    'heatMeters': [
      {
        'id': 'hm-1',
        'make': 'Kamstrup',
        'model': 'Multical 403',
        'location': 'Plant Room',
        'imagePaths': ['hm_1.jpg'],
      },
    ],
    'plateHeatExchangers': <Map<String, dynamic>>[],
    'heatGenerators': <Map<String, dynamic>>[],
    'dhwPlants': <Map<String, dynamic>>[],
    'communalControls': <Map<String, dynamic>>[],
    'dwellingInspections': <Map<String, dynamic>>[],
  },
  'observations': [
    {
      'id': 'obs-1',
      'questionReference': 'HNA.SITE.01',
      'notes': 'Minor corrosion noted.',
      'imagePaths': ['obs_1.jpg'],
      'is_unsafe': false,
    },
  ],
  'unsafe': {
    'unsafeObservations': <Map<String, dynamic>>[],
    'unsafeReports': <Map<String, dynamic>>[],
    'unreportedUnsafeObservations': <Map<String, dynamic>>[],
  },
};

Map<String, dynamic> _normalizeVolatile(Map<String, dynamic> payload) {
  final copy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
  _walkVolatile(copy);
  final form = copy['form'];
  if (form is Map && form.containsKey('id')) form['id'] = '<formId>';
  return copy;
}

void _walkVolatile(dynamic node) {
  if (node is Map) {
    for (final k in node.keys.toList()) {
      if (k == 'computedAt' || k == 'createdAt' || k == 'updatedAt') {
        node[k] = '<volatile>';
      } else if (k == 'formId') {
        node[k] = '<formId>';
      } else {
        _walkVolatile(node[k]);
      }
    }
  } else if (node is List) {
    for (final e in node) {
      _walkVolatile(e);
    }
  }
}

String _canonicalJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_sortDeep(value));

Object? _sortDeep(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in sortedKeys) k: _sortDeep(value[k])};
  }
  if (value is List) return value.map(_sortDeep).toList();
  return value;
}
