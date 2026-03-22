import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';

class FormResponseAttachmentSyncService {
  FormResponseAttachmentSyncService({required this.apiClient});

  final PortalApiClient apiClient;

  Future<void> syncDirectUploads({
    required String bearerToken,
    required String responseId,
    required List<Map<String, dynamic>> attachments,
    FormResponseAttachmentEndpoints? endpoints,
  }) async {
    final resolvedEndpoints =
        endpoints ?? FormResponseAttachmentEndpoints.forFormResponses();

    final manifestEntries = await _buildManifestEntries(attachments);
    if (manifestEntries.isEmpty) return;

    final missingIds = await _confirmManifest(
      bearerToken: bearerToken,
      manifestPath: resolvedEndpoints.manifestPath(responseId),
      entries: manifestEntries,
    );

    if (missingIds.isEmpty) return;

    final toUpload = manifestEntries
        .where((a) => missingIds.contains(a.attachmentId))
        .toList();

    final targets = await _requestUploadTargets(
      bearerToken: bearerToken,
      uploadTargetsPath: resolvedEndpoints.uploadTargetsPath(responseId),
      entries: toUpload,
    );

    final targetsById = {for (final t in targets) t.attachmentId: t};

    for (final a in toUpload) {
      final target = targetsById[a.attachmentId];
      if (target == null) {
        throw PortalApiException(
          'Missing direct upload target for attachment ${a.attachmentId}',
        );
      }

      await _uploadSingle(a, target);
    }

    final finalizeMissing = await _finalizeUploads(
      bearerToken: bearerToken,
      finalizePath: resolvedEndpoints.finalizePath(responseId),
      entries: toUpload,
    );

    if (finalizeMissing.isNotEmpty) {
      throw PortalApiException(
        'Attachment finalize failed. Missing: ${finalizeMissing.join(', ')}',
      );
    }
  }

  Future<Set<String>> _confirmManifest({
    required String bearerToken,
    required String manifestPath,
    required List<_ManifestEntry> entries,
  }) async {
    final json = await apiClient.postJson(
      manifestPath,
      bearerToken: bearerToken,
      body: {
        'attachments': entries
            .map(
              (a) => {
                'attachmentId': a.attachmentId,
                'contentType': a.contentType,
                'fileName': a.fileName,
                'fileSize': a.fileSize,
              },
            )
            .toList(),
      },
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ??
            'Attachment manifest confirmation failed',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) return {};

    final missing = data['missingAttachmentIds'];
    if (missing is! List) return {};

    return missing.map((e) => e.toString()).toSet();
  }

  Future<List<_UploadTarget>> _requestUploadTargets({
    required String bearerToken,
    required String uploadTargetsPath,
    required List<_ManifestEntry> entries,
  }) async {
    final json = await apiClient.postJson(
      uploadTargetsPath,
      bearerToken: bearerToken,
      body: {
        'attachments': entries
            .map(
              (a) => {
                'attachmentId': a.attachmentId,
                'contentType': a.contentType,
                'fileName': a.fileName,
                'fileSize': a.fileSize,
              },
            )
            .toList(),
      },
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ??
            'Failed to get direct upload targets',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) return const [];

    final uploads = data['uploads'];
    if (uploads is! List) return const [];

    return uploads.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final attachmentId = (map['attachmentId'] ?? '').toString().trim();
      final uploadUrl = (map['uploadUrl'] ?? '').toString().trim();
      final contentType = (map['contentType'] ?? '').toString().trim();
      if (attachmentId.isEmpty || uploadUrl.isEmpty || contentType.isEmpty) {
        throw PortalApiException('Malformed direct upload target response');
      }

      return _UploadTarget(
        attachmentId: attachmentId,
        uploadUrl: uploadUrl,
        contentType: contentType,
      );
    }).toList();
  }

  Future<Set<String>> _finalizeUploads({
    required String bearerToken,
    required String finalizePath,
    required List<_ManifestEntry> entries,
  }) async {
    final json = await apiClient.postJson(
      finalizePath,
      bearerToken: bearerToken,
      body: {
        'attachments': entries
            .map(
              (a) => {
                'attachmentId': a.attachmentId,
                'contentType': a.contentType,
                'fileName': a.fileName,
                'fileSize': a.fileSize,
              },
            )
            .toList(),
      },
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Attachment finalize failed',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) return {};

    final missing = data['missingAttachmentIds'];
    if (missing is! List) return {};

    return missing.map((e) => e.toString()).toSet();
  }

  Future<List<_ManifestEntry>> _buildManifestEntries(
    List<Map<String, dynamic>> attachments,
  ) async {
    final out = <_ManifestEntry>[];

    for (final raw in attachments) {
      final attachmentId = (raw['id'] ?? '').toString().trim();
      final localPath = (raw['localPath'] ?? '').toString().trim();
      if (attachmentId.isEmpty || localPath.isEmpty) continue;

      final resolvedPath = await _resolvePath(localPath);
      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw PortalApiException('Missing attachment file: $resolvedPath');
      }

      out.add(
        _ManifestEntry(
          attachmentId: attachmentId,
          resolvedPath: resolvedPath,
          fileName: p.basename(resolvedPath),
          contentType: raw['contentType']?.toString().trim(),
          fileSize: await file.length(),
        ),
      );
    }

    return out;
  }

  Future<String> _resolvePath(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    if (p.isAbsolute(trimmed)) return trimmed;
    if (trimmed.contains('://') || trimmed.startsWith('data:')) return trimmed;

    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, trimmed);
  }

  Future<void> _uploadSingle(_ManifestEntry entry, _UploadTarget target) async {
    final file = File(entry.resolvedPath);
    final req = http.Request('PUT', Uri.parse(target.uploadUrl));
    req.headers['Content-Type'] = target.contentType;
    req.bodyBytes = await file.readAsBytes();

    final resp = await apiClient.httpClient.send(req);
    final body = await resp.stream.bytesToString();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PortalApiException(
        body.isEmpty ? 'Direct attachment upload failed' : body,
        statusCode: resp.statusCode,
      );
    }
  }
}

class FormResponseAttachmentEndpoints {
  const FormResponseAttachmentEndpoints({
    required this.manifestPath,
    required this.uploadTargetsPath,
    required this.finalizePath,
  });

  final String Function(String responseId) manifestPath;
  final String Function(String responseId) uploadTargetsPath;
  final String Function(String responseId) finalizePath;

  factory FormResponseAttachmentEndpoints.forFormResponses() {
    return FormResponseAttachmentEndpoints(
      manifestPath: (responseId) =>
          '/api/forms/responses/$responseId/attachments/manifest',
      uploadTargetsPath: (responseId) =>
          '/api/forms/responses/$responseId/attachments/upload-targets',
      finalizePath: (responseId) =>
          '/api/forms/responses/$responseId/attachments/finalize',
    );
  }

  factory FormResponseAttachmentEndpoints.forHnaAssessments() {
    return FormResponseAttachmentEndpoints(
      manifestPath: (responseId) =>
          '/api/hna/assessments/$responseId/attachments/manifest',
      uploadTargetsPath: (responseId) =>
          '/api/hna/assessments/$responseId/attachments/upload-targets',
      finalizePath: (responseId) =>
          '/api/hna/assessments/$responseId/attachments/finalize',
    );
  }
}

class _ManifestEntry {
  const _ManifestEntry({
    required this.attachmentId,
    required this.resolvedPath,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
  });

  final String attachmentId;
  final String resolvedPath;
  final String fileName;
  final String? contentType;
  final int fileSize;
}

class _UploadTarget {
  const _UploadTarget({
    required this.attachmentId,
    required this.uploadUrl,
    required this.contentType,
  });

  final String attachmentId;
  final String uploadUrl;
  final String contentType;
}
