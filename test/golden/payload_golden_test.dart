// Golden regression for form payload serialization.
//
// These tests pin the exact JSON the payload builders produce for a fixed,
// representative input. The upcoming form-I/O repository refactor changes HOW
// data reaches these builders (SQLite vs server) but MUST NOT change the
// envelope the server stores. If a refactor alters the payload shape, these
// goldens fail — which is the data-preservation guard for live server data.
//
// The builders' only time source is `submittedAt`, which we pin, so output is
// fully deterministic.
//
// To intentionally regenerate goldens after an APPROVED contract change:
//   UPDATE_GOLDEN=1 flutter test test/golden/payload_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CR web payload (buildFromFormSnapshot) matches golden', () {
    final payload = CrSubmissionPayloadBuilder.buildFromFormSnapshot(
      formSnapshot: _representativeCrSnapshot(),
      originalPayload: _representativeOriginalCrPayload(),
      formId: 1234,
      formUuid: 'cr-uuid-fixed-0001',
      submittedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
    );
    _expectMatchesGolden('test/golden/cr_web_payload.json', payload);
  });
}

/// A structurally representative Condition Report form snapshot (the in-memory
/// shape the web editor edits): top-level fields plus the nested collections
/// and an image-bearing observation that exercises attachment extraction.
Map<String, dynamic> _representativeCrSnapshot() => {
  'client': 'Acme Housing',
  'siteName': 'Riverside Court',
  'auditorName': 'Jane Assessor',
  'auditDate': '2025-12-10',
  'assets': [
    {
      'id': 1,
      'assetTypeId': 7,
      'assetMake': 'Bosch',
      'assetModel': 'GB162',
      'location': 'Plant Room A',
      'operational': 'yes',
      'visualCondition': 'good',
      'imagePaths': ['asset_1_front.jpg'],
    },
  ],
  'plantRooms': [
    {
      'id': 1,
      'location': 'Basement',
      'accessImagePaths': ['plantroom_1_access.jpg'],
      'internalImagePaths': <String>[],
    },
  ],
  'observations': [
    {
      'id': 1,
      'questionReference': 'CR.SITE.01',
      'notes': 'Minor corrosion on flow pipe.',
      'imagePaths': ['obs_1_a.jpg', 'obs_1_b.jpg'],
      'isUnsafe': false,
    },
  ],
  'unsafe': {
    'unsafeObservations': <Map<String, dynamic>>[],
    'unsafeReports': <Map<String, dynamic>>[],
  },
};

/// The prior server payload the editor loaded (web edits merge onto this).
Map<String, dynamic> _representativeOriginalCrPayload() => {
  'payloadSchemaVersion': 2,
  'form': {
    'formType': 'conditionReport',
    'formId': 1234,
    'uuid': 'cr-uuid-fixed-0001',
    'submittedAtUtc': '2025-12-11T09:00:00.000Z',
  },
  'conditionReport': {
    'client': 'Acme Housing (old)',
    'siteName': 'Riverside Court',
  },
};

// --- golden comparison helpers ---------------------------------------------

void _expectMatchesGolden(String relativePath, Map<String, dynamic> payload) {
  final actual = _canonicalJson(payload);
  final file = File(relativePath);
  final update = Platform.environment['UPDATE_GOLDEN'] == '1';

  if (!file.existsSync() || update) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    // First-run / explicit regeneration establishes the baseline.
    return;
  }

  final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
  expect(
    actual,
    expected,
    reason:
        'Payload shape changed vs golden ($relativePath). If this is an '
        'INTENDED, approved contract change, regenerate with UPDATE_GOLDEN=1.',
  );
}

/// Stable, key-sorted, pretty JSON so ordering never causes false diffs.
String _canonicalJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(_sortDeep(value))}\n';
}

Object? _sortDeep(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in sortedKeys) k: _sortDeep(value[k])};
  }
  if (value is List) {
    return value.map(_sortDeep).toList();
  }
  return value;
}
