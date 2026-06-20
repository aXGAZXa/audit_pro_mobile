import 'dart:io';

import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

/// One captured image queued for direct R2 upload on submit.
///
/// Resolved from the generic form's image-question answers (each answer is a
/// list of [gtmobile.GTImage] ids -> a [gtmobile.GTImage] row in the
/// `gt_images` table via [gtmobile.GTDatabaseService]).
class GenericPendingAttachment {
  const GenericPendingAttachment({
    required this.attachmentId,
    required this.localPath,
    required this.contentType,
    required this.fileName,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  /// Stable per-image id (the [gtmobile.GTImage.id]).
  final String attachmentId;

  /// On-device path to the captured image bytes (from [gtmobile.GTImage.localPath]).
  final String localPath;

  /// MIME type, e.g. `image/jpeg`.
  final String contentType;
  final String fileName;
  final int sizeBytes;
  final int? width;
  final int? height;
}

/// The result of a successful direct R2 upload: the deterministic server key
/// plus the metadata that goes into the generic submit envelope's
/// `attachments[]` (path-only delivery model).
class GenericUploadedAttachment {
  const GenericUploadedAttachment({
    required this.attachmentId,
    required this.key,
    required this.contentType,
    required this.fileName,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  final String attachmentId;

  /// The deterministic R2 object key the server derived, e.g.
  /// `generic/<tenant>/<app>/<clientResponseId>/att_0001.jpg`. This is the ONLY
  /// thing delivered in the envelope.
  final String key;
  final String contentType;
  final String fileName;
  final int sizeBytes;
  final int? width;
  final int? height;

  /// The envelope `attachments[]` object shape (path-only).
  Map<String, dynamic> toEnvelopeJson() => <String, dynamic>{
        'id': attachmentId,
        'key': key,
        'contentType': contentType,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

/// Raised when one or more attachments could not be uploaded to R2 (e.g.
/// offline, presign failure, or a failed PUT). The caller MUST surface this to
/// the user and abort the submit — images are NOT silently dropped.
class GenericAttachmentUploadException implements Exception {
  GenericAttachmentUploadException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'GenericAttachmentUploadException: $message';
}

/// Uploads generic (builder-authored) form images straight to Cloudflare R2 on
/// submit, using a presigned-PUT contract.
///
/// Two stages (no manifest/finalize — the server derives keys deterministically
/// and the envelope carries them):
///   1. `POST /api/mobile/generic-forms/attachments/upload-targets` to mint a
///      presigned PUT url + the deterministic key for each image.
///   2. PUT the raw image bytes to each `uploadUrl` with `requiredHeaders`.
///
/// Mirrors the auth + base-URL pattern used by [GenericFormSubmissionService]
/// and reuses [FormResponseAttachmentSyncService]'s presigned-PUT semantics
/// (same [PortalApiClient.httpClient], bearer mobile JWT).
///
/// NON-DISRUPTIVE: brand-new path used only by the generic submit flow; does NOT
/// touch the live CR/HNA attachment sync.
class GenericFormAttachmentUploadService {
  GenericFormAttachmentUploadService({PortalApiClient? apiClient})
      : apiClient =
            apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final PortalApiClient apiClient;

  /// FIXED upload-targets endpoint (forms-unification attachment contract).
  static const String uploadTargetsPath =
      '/api/mobile/generic-forms/attachments/upload-targets';

  /// Resolves the [gtmobile.GTImage] ids referenced by every image question in
  /// [package] to [GenericPendingAttachment]s (localPath/mime/size/dims) using
  /// the generic forms DB ([gtmobile.GTDatabaseService]).
  ///
  /// Returns an empty list when the form has no image questions or no captured
  /// images — in that case the submit proceeds unchanged with an empty
  /// `attachments[]`.
  Future<List<GenericPendingAttachment>> collectPendingAttachments({
    required gtmobile.FormPackage package,
    required Map<String, dynamic> responseJson,
  }) async {
    final imageQuestions = <gtmobile.ImageQuestion>[];
    for (final section in package.formDefinition.sections) {
      imageQuestions.addAll(
        section.getAllElementsOfType<gtmobile.ImageQuestion>(),
      );
    }
    if (imageQuestions.isEmpty) return const [];

    final answers = responseJson['answers'];
    final answerMap =
        answers is Map ? Map<String, dynamic>.from(answers) : const {};

    // Preserve order + de-dupe ids (same image could in theory be referenced
    // twice; the attachmentId is unique so we keep the first).
    final imageIds = <String>[];
    final seen = <String>{};
    for (final q in imageQuestions) {
      final answer = answerMap[q.id];
      for (final id in _readImageIds(answer)) {
        if (seen.add(id)) imageIds.add(id);
      }
    }
    if (imageIds.isEmpty) return const [];

    final db = gtmobile.GTDatabaseService.instance;
    final pending = <GenericPendingAttachment>[];
    for (final id in imageIds) {
      final result =
          await db.fetchByIdAsync<gtmobile.GTImage>(id);
      final image = result.data;
      if (image == null) {
        throw GenericAttachmentUploadException(
          'A captured photo is missing from local storage (id=$id).',
        );
      }

      final localPath = image.localPath.trim();
      if (localPath.isEmpty) {
        throw GenericAttachmentUploadException(
          'A captured photo has no local file (id=$id).',
        );
      }

      final resolvedPath = await _resolvePath(localPath);
      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw GenericAttachmentUploadException(
          'A captured photo file is missing on device: $resolvedPath',
        );
      }

      final size =
          image.fileSizeBytes > 0 ? image.fileSizeBytes : await file.length();
      final contentType =
          image.mimeType.trim().isNotEmpty ? image.mimeType.trim() : 'image/jpeg';
      final fileName = image.fileName.trim().isNotEmpty
          ? image.fileName.trim()
          : p.basename(resolvedPath);

      pending.add(
        GenericPendingAttachment(
          attachmentId: image.id,
          localPath: resolvedPath,
          contentType: contentType,
          fileName: fileName,
          sizeBytes: size,
          width: image.width,
          height: image.height,
        ),
      );
    }

    return pending;
  }

  /// Presigns + PUTs every [pending] image to R2 and returns the uploaded
  /// metadata (with the deterministic key) for the envelope's `attachments[]`.
  ///
  /// Throws [GenericAttachmentUploadException] on ANY failure (presign or PUT)
  /// so the caller can abort the submit and keep the draft/local images.
  Future<List<GenericUploadedAttachment>> upload({
    required String bearerToken,
    required String clientResponseId,
    required List<GenericPendingAttachment> pending,
  }) async {
    if (pending.isEmpty) return const [];

    final targets = await _requestUploadTargets(
      bearerToken: bearerToken,
      clientResponseId: clientResponseId,
      pending: pending,
    );
    final targetsById = {for (final t in targets) t.attachmentId: t};

    final uploaded = <GenericUploadedAttachment>[];
    for (final a in pending) {
      final target = targetsById[a.attachmentId];
      if (target == null) {
        throw GenericAttachmentUploadException(
          'Server did not return an upload target for photo ${a.attachmentId}.',
        );
      }

      await _putToR2(a, target);

      uploaded.add(
        GenericUploadedAttachment(
          attachmentId: a.attachmentId,
          key: target.key,
          contentType: a.contentType,
          fileName: a.fileName,
          sizeBytes: a.sizeBytes,
          width: a.width,
          height: a.height,
        ),
      );
    }

    ApmLogger.info(
      'Generic attachments uploaded count={Count} clientResponseId=$clientResponseId',
      args: [uploaded.length],
      category: 'GenericForms/Attachments',
    );

    return uploaded;
  }

  Future<List<_UploadTarget>> _requestUploadTargets({
    required String bearerToken,
    required String clientResponseId,
    required List<GenericPendingAttachment> pending,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await apiClient.postJson(
        uploadTargetsPath,
        bearerToken: bearerToken,
        body: {
          'clientResponseId': clientResponseId,
          'items': pending
              .map(
                (a) => {
                  'attachmentId': a.attachmentId,
                  'contentType': a.contentType,
                  'fileName': a.fileName,
                  'sizeBytes': a.sizeBytes,
                },
              )
              .toList(),
        },
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Generic upload-targets request failed clientResponseId=$clientResponseId: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Attachments',
        error: e,
        stackTrace: st,
      );
      throw GenericAttachmentUploadException(
        "Couldn't upload photos — check your connection and try again.",
        cause: e,
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) {
      throw GenericAttachmentUploadException(
        'Server returned no upload targets for photos.',
      );
    }

    final items = data['items'];
    if (items is! List || items.isEmpty) {
      throw GenericAttachmentUploadException(
        'Server returned no upload targets for photos.',
      );
    }

    return items.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final attachmentId = (map['attachmentId'] ?? '').toString().trim();
      final key = (map['key'] ?? '').toString().trim();
      final uploadUrl = (map['uploadUrl'] ?? '').toString().trim();
      if (attachmentId.isEmpty || key.isEmpty || uploadUrl.isEmpty) {
        throw GenericAttachmentUploadException(
          'Malformed upload target from server.',
        );
      }

      final headersRaw = map['requiredHeaders'];
      final headers = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((k, v) {
          headers[k.toString()] = v.toString();
        });
      }

      return _UploadTarget(
        attachmentId: attachmentId,
        key: key,
        uploadUrl: uploadUrl,
        requiredHeaders: headers,
      );
    }).toList();
  }

  Future<void> _putToR2(
    GenericPendingAttachment a,
    _UploadTarget target,
  ) async {
    try {
      final file = File(a.localPath);
      final req = http.Request('PUT', Uri.parse(target.uploadUrl));
      // Use the server-specified required headers (Content-Type) verbatim; fall
      // back to the image's own content type if none were supplied.
      if (target.requiredHeaders.isEmpty) {
        req.headers['Content-Type'] = a.contentType;
      } else {
        req.headers.addAll(target.requiredHeaders);
      }
      req.bodyBytes = await file.readAsBytes();

      final resp = await apiClient.httpClient.send(req);
      final body = await resp.stream.bytesToString();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw GenericAttachmentUploadException(
          body.isEmpty
              ? 'Photo upload failed (HTTP ${resp.statusCode}).'
              : body,
        );
      }
    } on GenericAttachmentUploadException {
      rethrow;
    } catch (e, st) {
      ApmLogger.warning(
        'Generic R2 PUT failed attachmentId=${a.attachmentId}: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Attachments',
        error: e,
        stackTrace: st,
      );
      throw GenericAttachmentUploadException(
        "Couldn't upload photos — check your connection and try again.",
        cause: e,
      );
    }
  }

  Iterable<String> _readImageIds(dynamic answer) {
    if (answer is List) {
      return answer
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty);
    }
    if (answer is String && answer.trim().isNotEmpty) {
      return [answer.trim()];
    }
    return const [];
  }

  Future<String> _resolvePath(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (p.isAbsolute(trimmed)) return trimmed;
    if (trimmed.contains('://') || trimmed.startsWith('data:')) return trimmed;

    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, trimmed);
  }
}

class _UploadTarget {
  const _UploadTarget({
    required this.attachmentId,
    required this.key,
    required this.uploadUrl,
    required this.requiredHeaders,
  });

  final String attachmentId;
  final String key;
  final String uploadUrl;
  final Map<String, String> requiredHeaders;
}
