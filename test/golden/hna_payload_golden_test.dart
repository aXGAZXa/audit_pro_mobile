// HNA v4 payload golden — the non-negotiable safety net before touching any
// observation infrastructure shared with HNA.
//
// Pins `HnaSubmissionPayloadBuilder.build` output for a fixed, representative
// HNA draft. The Capture & Projection refactor changes HOW data reaches this
// builder (single-writer repo plumbing) but MUST NOT change the v4 envelope.
// If the payload shape drifts, this fails — the data-preservation guard for
// live HNA server data.
//
// `submittedAt` is pinned; the only other non-determinism is the form row's
// created/updated timestamps, which we normalize out before comparison.
//
// Regenerate after an APPROVED contract change:
//   UPDATE_GOLDEN=1 flutter test test/golden/hna_payload_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('HNA build() payload matches golden (v4 regression net)', () async {
    final db = DatabaseHelper.instance;

    final formId = await db.saveForm(
      formType: kHeatNetworkAssessmentFormType,
      status: 'draft',
      uuid: 'hna-uuid-fixed-0001',
      formData: _representativeHnaDraft(),
    );

    final payload = await HnaSubmissionPayloadBuilder.build(
      formId: formId,
      db: db,
      submittedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
    );

    expect(payload, isNotNull);
    _expectMatchesGolden('test/golden/hna_payload.json', payload!);
  });
}

/// A structurally representative HNA draft document (the `form_data` blob):
/// top-level `formData`, the `assets` sub-collections, observations, unsafe.
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

// --- golden comparison helpers ---------------------------------------------

void _expectMatchesGolden(String relativePath, Map<String, dynamic> payload) {
  final actual = _canonicalJson(_normalizeVolatile(payload));
  final file = File(relativePath);
  final update = Platform.environment['UPDATE_GOLDEN'] == '1';

  if (!file.existsSync() || update) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }

  final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
  expect(
    actual,
    expected,
    reason:
        'HNA v4 payload shape changed vs golden ($relativePath). If this is an '
        'INTENDED, approved contract change, regenerate with UPDATE_GOLDEN=1.',
  );
}

/// Replace non-deterministic values so the golden is stable across runs:
///  - DB row timestamps (`createdAt`/`updatedAt`) and calculator `computedAt`
///    (these are `DateTime.now()` stamps), anywhere in the tree → '<volatile>'
///  - the autoincrement form id (`form.id` and the echoed `summary.formId`) →
///    '<formId>' (the shared ffi DB persists between runs, so it climbs)
/// The cross-device stable identity (`formUuid`, `friendlyRef`) is preserved.
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

String _canonicalJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(_sortDeep(value))}\n';
}

Object? _sortDeep(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in sortedKeys) k: _sortDeep(value[k])};
  }
  if (value is List) return value.map(_sortDeep).toList();
  return value;
}
