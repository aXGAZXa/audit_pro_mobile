import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/condition_report_definition.dart';

class CrSubmissionPayloadBuilder {
  static const int payloadSchemaVersion = 2;

  static Future<Map<String, dynamic>?> build({
    required int formId,
    DatabaseHelper? db,
    DateTime? submittedAt,
  }) async {
    final database = db ?? DatabaseHelper.instance;
    final form = await database.getForm(formId);
    if (form == null) return null;

    final formDataRaw = form['form_data'];
    final formData = formDataRaw is Map
        ? Map<String, dynamic>.from(formDataRaw)
        : <String, dynamic>{};

    final assets = await database.getAssets(formId);
    final plantRooms = await database.getPlantRooms(formId);
    final observations = await database.getFormObservations(formId);
    final unsafeObservations = await database.getUnsafeObservations(formId);
    final unsafeReports = await database.getUnsafeReports(formId);

    final conditionReport = <String, dynamic>{...formData};
    conditionReport['assets'] = assets;
    conditionReport['plantRooms'] = plantRooms;
    conditionReport['observations'] = observations;
    conditionReport['unsafe'] = {
      'unsafeObservations': unsafeObservations,
      'unsafeReports': unsafeReports,
    };

    final attachments = _buildAttachments(conditionReport);
    if (attachments.isNotEmpty) {
      final byPath = {
        for (final a in attachments)
          (a['localPath'] ?? '').toString(): (a['id'] ?? '').toString(),
      };
      _rewriteAttachmentRefsInPlace(conditionReport, byPath);
      conditionReport['attachments'] = attachments;
    }

    final submittedAtUtc = (submittedAt ?? DateTime.now().toUtc())
        .toIso8601String();

    return {
      'payloadSchemaVersion': payloadSchemaVersion,
      'form': {
        'formType': kConditionReportFormType,
        'formId': form['id'],
        'uuid': form['uuid'],
        'submittedAtUtc': submittedAtUtc,
      },
      'conditionReport': conditionReport,
    };
  }

  static Map<String, dynamic> buildFromFormSnapshot({
    required Map<String, dynamic> formSnapshot,
    Map<String, dynamic>? originalPayload,
    int? formId,
    String? formUuid,
    DateTime? submittedAt,
  }) {
    final payload = originalPayload == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(originalPayload);

    final originalCrRaw = payload['conditionReport'];
    final originalCr = originalCrRaw is Map
        ? Map<String, dynamic>.from(originalCrRaw)
        : <String, dynamic>{};

    final conditionReport = <String, dynamic>{
      ...originalCr,
      ..._normalizeMap(formSnapshot),
    };

    final attachments = _buildAttachments(conditionReport);
    if (attachments.isNotEmpty) {
      final byPath = {
        for (final a in attachments)
          (a['localPath'] ?? '').toString(): (a['id'] ?? '').toString(),
      };
      _rewriteAttachmentRefsInPlace(conditionReport, byPath);
      conditionReport['attachments'] = attachments;
    }

    payload['payloadSchemaVersion'] = payloadSchemaVersion;

    final submittedAtUtc = (submittedAt ?? DateTime.now().toUtc())
        .toIso8601String();

    final originalFormRaw = payload['form'];
    final form = originalFormRaw is Map
        ? Map<String, dynamic>.from(originalFormRaw)
        : <String, dynamic>{};

    form['formType'] = kConditionReportFormType;
    form['submittedAtUtc'] = submittedAtUtc;

    final resolvedFormId = formId ?? _tryParseInt(form['formId']);
    if (resolvedFormId != null) {
      form['formId'] = resolvedFormId;
    }

    final resolvedUuid = (formUuid ?? form['uuid'] ?? '').toString().trim();
    if (resolvedUuid.isNotEmpty) {
      form['uuid'] = resolvedUuid;
    }

    payload['form'] = form;
    payload['conditionReport'] = conditionReport;
    return payload;
  }

  static Map<String, dynamic> _normalizeMap(Map<String, dynamic> source) {
    final out = <String, dynamic>{};
    source.forEach((key, value) {
      out[key] = _jsonify(value);
    });
    return out;
  }

  static dynamic _jsonify(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is bool || value is String) return value;
    if (value is List) return value.map(_jsonify).toList(growable: false);
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, nested) {
        out[key.toString()] = _jsonify(nested);
      });
      return out;
    }
    return value.toString();
  }

  static int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static List<Map<String, dynamic>> _buildAttachments(
    Map<String, dynamic> conditionReport,
  ) {
    final paths = <String>{};

    void collect(dynamic node, {String? keyHint}) {
      if (node is Map) {
        node.forEach((k, v) => collect(v, keyHint: k.toString()));
        return;
      }

      if (node is List) {
        final listKey = (keyHint ?? '').toLowerCase();
        for (final v in node) {
          if (v is String && _isAttachmentCandidate(v, listKey)) {
            paths.add(v.trim());
            continue;
          }
          collect(v, keyHint: keyHint);
        }
        return;
      }

      if (node is String) {
        final key = (keyHint ?? '').toLowerCase();
        if (_isAttachmentCandidate(node, key)) {
          paths.add(node.trim());
        }
      }
    }

    collect(conditionReport);

    final sorted = paths.toList()..sort();
    final attachments = <Map<String, dynamic>>[];
    for (var i = 0; i < sorted.length; i++) {
      final path = sorted[i];
      attachments.add({
        'id': 'att_${(i + 1).toString().padLeft(4, '0')}',
        'localPath': path,
        'contentType': _inferContentType(path),
      });
    }

    return attachments;
  }

  static bool _isAttachmentCandidate(String value, String keyHint) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('att_')) return false;

    final looksLikeImagePath =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');

    final hasPathLikePrefix =
        lower.startsWith('/data/user/') ||
        lower.startsWith('file:///') ||
        lower.contains('/') ||
        lower.contains('\\');

    if (looksLikeImagePath && hasPathLikePrefix) {
      return true;
    }

    final key = keyHint.toLowerCase();
    final keyLooksLikeFileRef =
        key.contains('image') ||
        key.contains('signature') ||
        key.contains('photo') ||
        key.endsWith('path') ||
        key.endsWith('paths');

    if (!keyLooksLikeFileRef) return false;

    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:')) {
      return false;
    }

    return looksLikeImagePath || lower.startsWith('/data/user/');
  }

  static void _rewriteAttachmentRefsInPlace(
    dynamic node,
    Map<String, String> byPath,
  ) {
    if (node is Map) {
      final keys = node.keys.toList();
      for (final k in keys) {
        final value = node[k];
        if (value is String) {
          final id = byPath[value.trim()];
          if (id != null && id.isNotEmpty) {
            node[k] = id;
          }
          continue;
        }

        if (value is List) {
          for (var i = 0; i < value.length; i++) {
            final current = value[i];
            if (current is String) {
              final id = byPath[current.trim()];
              if (id != null && id.isNotEmpty) {
                value[i] = id;
                continue;
              }
            }
            _rewriteAttachmentRefsInPlace(current, byPath);
          }
          continue;
        }

        _rewriteAttachmentRefsInPlace(value, byPath);
      }
      return;
    }

    if (node is List) {
      for (var i = 0; i < node.length; i++) {
        final current = node[i];
        if (current is String) {
          final id = byPath[current.trim()];
          if (id != null && id.isNotEmpty) {
            node[i] = id;
            continue;
          }
        }
        _rewriteAttachmentRefsInPlace(current, byPath);
      }
    }
  }

  static String? _inferContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return null;
  }
}
