import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'hna_web_editor_service.dart';

/// Web-editor-only attachment context.
///
/// - Maps existing payload attachment `localPath` values to their `id`
/// - Uploads newly picked images (add-only) via editor-ticket endpoints
/// - Loads attachment bytes using ticket-authenticated requests
///
/// This context is intentionally scoped to the embedded HNA web editor.
class HnaWebEditorAttachmentContext {
  HnaWebEditorAttachmentContext._();

  static final HnaWebEditorAttachmentContext instance =
      HnaWebEditorAttachmentContext._();

  HnaWebEditorService? _service;
  String? _ticket;
  String? _submissionId;

  final Map<String, String> _localPathToAttachmentId = {};
  final Map<String, Map<String, dynamic>> _attachmentMetadataById = {};
  final Map<String, Uint8List> _bytesCache = {};
  final List<Map<String, dynamic>> _pendingAttachments = [];

  int _nextNumericAttachmentId = 1;

  bool get isConfigured =>
      kIsWeb &&
      _service != null &&
      _ticket != null &&
      _ticket!.trim().isNotEmpty &&
      _submissionId != null &&
      _submissionId!.trim().isNotEmpty;

  void configure({
    required HnaWebEditorService service,
    required String ticket,
    required String submissionId,
    List<Map<String, dynamic>>? initialAttachments,
  }) {
    _service = service;
    _ticket = ticket.trim();
    _submissionId = submissionId.trim();
    _localPathToAttachmentId.clear();
    _attachmentMetadataById.clear();
    _bytesCache.clear();
    _pendingAttachments.clear();

    var maxNumeric = 0;
    if (initialAttachments != null) {
      for (final raw in initialAttachments) {
        final map = Map<String, dynamic>.from(raw);
        final id = (map['id'] ?? map['Id'] ?? '').toString().trim();
        if (id.isEmpty) continue;

        _attachmentMetadataById[id] = map;

        final localPath = (map['localPath'] ?? map['LocalPath'] ?? '')
            .toString()
            .trim();

        if (localPath.isNotEmpty) {
          _localPathToAttachmentId[localPath] = id;
        }

        final m = RegExp(r'^att_(\d+)$').firstMatch(id);
        if (m != null) {
          final n = int.tryParse(m.group(1) ?? '');
          if (n != null && n > maxNumeric) maxNumeric = n;
        }
      }
    }

    _nextNumericAttachmentId = maxNumeric + 1;
  }

  bool knowsLocalPath(String localPath) {
    final key = localPath.trim();
    if (key.isEmpty) return false;
    if (_localPathToAttachmentId.containsKey(key)) return true;
    final base = p.basename(key);
    if (base.isEmpty) return false;
    return _localPathToAttachmentId.keys.any((k) => p.basename(k) == base);
  }

  String? resolveAttachmentIdForLocalPath(String localPath) {
    final key = localPath.trim();
    if (key.isEmpty) return null;
    final direct = _localPathToAttachmentId[key];
    if (direct != null && direct.trim().isNotEmpty) return direct;

    // Back-compat: payloads may contain full device paths but some callers
    // normalize to basenames.
    final base = p.basename(key);
    if (base.isEmpty) return null;

    String? match;
    for (final entry in _localPathToAttachmentId.entries) {
      if (p.basename(entry.key) != base) continue;
      if (match != null && match != entry.value) {
        // Ambiguous basename.
        return null;
      }
      match = entry.value;
    }
    return match;
  }

  Future<Uint8List?> loadBytesForLocalPath(String localPath) async {
    if (!isConfigured) return null;

    final key = localPath.trim();
    if (key.isEmpty) return null;

    final cached = _bytesCache[key];
    if (cached != null) return cached;

    final attachmentId = resolveAttachmentIdForLocalPath(key);
    if (attachmentId == null) return null;

    final bytes = await _service!.getAttachmentBytes(
      ticket: _ticket!,
      attachmentId: attachmentId,
    );
    final out = Uint8List.fromList(bytes);
    _bytesCache[key] = out;
    return out;
  }

  Future<String> uploadNewImage({
    required XFile image,
    required String prefix,
  }) async {
    if (!isConfigured) {
      return image.path;
    }

    final attachmentId = _nextAttachmentId(prefix: prefix);
    final bytes = await image.readAsBytes();

    final ext = _safeImageExtension(
      p.extension(image.name.isNotEmpty ? image.name : image.path),
    );
    final fileName = '$attachmentId$ext';
    final contentType = ext.toLowerCase() == '.png'
        ? 'image/png'
        : ext.toLowerCase() == '.webp'
        ? 'image/webp'
        : 'image/jpeg';

    await _service!.uploadAttachment(
      ticket: _ticket!,
      attachmentId: attachmentId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    final attachmentJson = <String, dynamic>{
      'id': attachmentId,
      // Intentionally store a filename-style localPath (not a full device path).
      'localPath': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
    };

    _pendingAttachments.add(attachmentJson);
    _localPathToAttachmentId[fileName] = attachmentId;
    _attachmentMetadataById[attachmentId] = attachmentJson;

    return fileName;
  }

  List<Map<String, dynamic>> buildManifest({
    required int formId,
    required Map<String, dynamic> formData,
    required Map<String, dynamic> assetsJson,
    required List<Map<String, dynamic>> observationsJson,
    required Map<String, dynamic> unsafeJson,
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

      (entry['links'] as List<Map<String, dynamic>>).add({
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
      for (final localPath in localPaths) {
        if (localPath == null) continue;
        addLink(
          localPath: localPath.toString(),
          ownerType: ownerType,
          ownerId: ownerId,
          field: field,
          role: role,
        );
      }
    }

    final siteRepSig = (formData['siteRepSignature'] ?? '').toString().trim();
    if (siteRepSig.isNotEmpty) {
      addLink(
        localPath: siteRepSig,
        ownerType: 'form',
        ownerId: formId,
        field: 'siteRepSignature',
        role: 'signature_site_rep',
      );
    }

    final auditorSig = (formData['auditorSignature'] ?? '').toString().trim();
    if (auditorSig.isNotEmpty) {
      addLink(
        localPath: auditorSig,
        ownerType: 'form',
        ownerId: formId,
        field: 'auditorSignature',
        role: 'signature_auditor',
      );
    }

    void collectAssetPhotos(
      String listKey,
      String ownerType, {
      String field = 'imagePaths',
      String role = 'photo',
    }) {
      for (final raw in (assetsJson[listKey] as List? ?? const [])) {
        final item = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (item == null) continue;
        addLinksFromList(
          localPaths: item[field] as List?,
          ownerType: ownerType,
          ownerId: item['id'],
          field: field,
          role: role,
        );
      }
    }

    collectAssetPhotos('heatMeters', 'heat_meter');
    collectAssetPhotos('plateHeatExchangers', 'plate_heat_exchanger');
    collectAssetPhotos('heatGenerators', 'heat_generator');
    collectAssetPhotos('dhwPlants', 'dhw_plant');
    collectAssetPhotos('communalControls', 'communal_control');

    for (final raw
        in (assetsJson['dwellingInspections'] as List? ?? const [])) {
      final item = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (item == null) continue;

      addLinksFromList(
        localPaths: item['imagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: item['id'],
        field: 'imagePaths',
        role: 'photo',
      );
      addLinksFromList(
        localPaths: item['heatingImagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: item['id'],
        field: 'heatingImagePaths',
        role: 'photo_heating',
      );
      addLinksFromList(
        localPaths: item['dhwImagePaths'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: item['id'],
        field: 'dhwImagePaths',
        role: 'photo_dhw',
      );
      addLinksFromList(
        localPaths: item['heatingSubMeterEvidenceImages'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: item['id'],
        field: 'heatingSubMeterEvidenceImages',
        role: 'evidence_heating_submeter',
      );
      addLinksFromList(
        localPaths: item['dhwSubMeterEvidenceImages'] as List?,
        ownerType: 'dwelling_inspection',
        ownerId: item['id'],
        field: 'dhwSubMeterEvidenceImages',
        role: 'evidence_dhw_submeter',
      );
    }

    void collectObservationList(
      List<Map<String, dynamic>> source, {
      required String listRole,
    }) {
      for (final item in source) {
        final observationId = item['id'];
        addLinksFromList(
          localPaths: (item['imagePaths'] ?? item['images']) as List?,
          ownerType: 'observation',
          ownerId: observationId,
          field: 'imagePaths',
          role: 'photo_$listRole',
        );

        final warning = (item['unsafeWarningNoticeImage'] ?? '')
            .toString()
            .trim();
        if (warning.isNotEmpty) {
          addLink(
            localPath: warning,
            ownerType: 'observation',
            ownerId: observationId,
            field: 'unsafeWarningNoticeImage',
            role: 'unsafe_warning_notice_$listRole',
          );
        }

        final after = (item['unsafeAfterImage'] ?? '').toString().trim();
        if (after.isNotEmpty) {
          addLink(
            localPath: after,
            ownerType: 'observation',
            ownerId: observationId,
            field: 'unsafeAfterImage',
            role: 'unsafe_after_$listRole',
          );
        }
      }
    }

    collectObservationList(observationsJson, listRole: 'general');
    collectObservationList(
      _asMapList(unsafeJson['unsafeObservations']),
      listRole: 'unsafe',
    );
    collectObservationList(
      _asMapList(unsafeJson['unreportedUnsafeObservations']),
      listRole: 'unsafe_unreported',
    );

    for (final item in _asMapList(unsafeJson['unsafeReports'])) {
      final reportId = item['id'];
      final warning = (item['warningNoticeImage'] ?? '').toString().trim();
      if (warning.isNotEmpty) {
        addLink(
          localPath: warning,
          ownerType: 'unsafe_report',
          ownerId: reportId,
          field: 'warningNoticeImage',
          role: 'unsafe_report_warning_notice',
        );
      }

      final after = (item['afterImage'] ?? '').toString().trim();
      if (after.isNotEmpty) {
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
      ..sort((left, right) => left.key.compareTo(right.key));

    final manifest = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final localPath = entry.key;
      final attachmentId =
          resolveAttachmentIdForLocalPath(localPath) ??
          _nextAttachmentId(prefix: 'att');
      _localPathToAttachmentId[localPath] = attachmentId;

      final existingMetadata = Map<String, dynamic>.from(
        _attachmentMetadataById[attachmentId] ?? const <String, dynamic>{},
      );

      final attachment = <String, dynamic>{
        ...existingMetadata,
        'id': attachmentId,
        'localPath': localPath,
        'contentType':
            entry.value['contentType'] ?? existingMetadata['contentType'],
        'links': entry.value['links'],
      };

      _attachmentMetadataById[attachmentId] = Map<String, dynamic>.from(
        attachment,
      );
      manifest.add(attachment);
    }

    return manifest;
  }

  List<Map<String, dynamic>> mergeAttachments(
    List<Map<String, dynamic>> existing,
  ) {
    if (_pendingAttachments.isEmpty) {
      return existing.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final raw in existing) {
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? map['Id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (seen.add(id)) out.add(map);
    }

    for (final raw in _pendingAttachments) {
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? map['Id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (seen.add(id)) out.add(map);
    }

    return out;
  }

  void commitPending() {
    _pendingAttachments.clear();
  }

  String _nextAttachmentId({required String prefix}) {
    // Prefer the att_#### format when possible.
    final n = _nextNumericAttachmentId++;
    final numericId = 'att_${n.toString().padLeft(4, '0')}';
    return numericId;
  }

  String _safeImageExtension(String ext) {
    final trimmed = ext.trim();
    if (trimmed.isEmpty) return '.jpg';
    final lower = trimmed.toLowerCase();
    if (lower == '.jpg' ||
        lower == '.jpeg' ||
        lower == '.png' ||
        lower == '.webp') {
      return lower == '.jpeg' ? '.jpg' : lower;
    }
    return '.jpg';
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String? _inferContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return null;
  }
}
