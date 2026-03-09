import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_payload_builder.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_edit_sessions_service.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/jwt_debug.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';

class HnaSubmissionService {
  HnaSubmissionService({
    required this.tokenStore,
    required this.appInfoService,
    PortalApiClient? apiClient,
    DatabaseHelper? db,
  }) : apiClient =
           apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl),
       db = db ?? DatabaseHelper.instance;

  final AuthTokenStore tokenStore;
  final AppInfoService appInfoService;
  final PortalApiClient apiClient;
  final DatabaseHelper db;

  final HnaEditSessionsService _editSessions = HnaEditSessionsService();

  static const String _submissionSummaryKey = 'submissionSummary';
  static const String _editSessionKey = 'editSession';

  static final RegExp _guidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<Map<String, dynamic>?> _readEditSession({required int formId}) async {
    try {
      final form = await db.getForm(formId);
      if (form == null) return null;

      final root = Map<String, dynamic>.from(form['form_data'] as Map);

      // Backwards/forwards compatibility:
      // - historically some callers stored editSession at the root of form_data
      // - newer draft docs store it under form_data.formData.editSession
      final raw =
          root[_editSessionKey] ??
          ((root['formData'] is Map)
              ? (root['formData'] as Map)[_editSessionKey]
              : null);
      if (raw is! Map) return null;

      final m = Map<String, dynamic>.from(raw);
      final token = (m['sessionToken'] ?? '').toString().trim();
      if (token.isEmpty) return null;

      return m;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime> _readStableSubmittedAt({
    required int formId,
    required DateTime fallback,
  }) async {
    try {
      final form = await db.getForm(formId);
      if (form == null) return fallback;

      final root = Map<String, dynamic>.from(form['form_data'] as Map);

      // Similar compatibility to _readEditSession():
      // submissionSummary may be stored at root or under formData.
      final raw =
          root[_submissionSummaryKey] ??
          ((root['formData'] is Map)
              ? (root['formData'] as Map)[_submissionSummaryKey]
              : null);
      if (raw is! Map) return fallback;

      final submittedAtRaw = (raw['submittedAt'] ?? '').toString().trim();
      final parsed = DateTime.tryParse(submittedAtRaw);
      return parsed ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<String?> submitForm({required int formId}) async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw PortalApiException('You are not signed in.');
    }

    ApmLogger.info(
      'Submit start formId=$formId baseUrl=${apiClient.baseUrl} jwt=${maskToken(token)} ${describeJwtForLogs(token)}',
      category: 'HNA/Submit',
    );

    final attemptAt = DateTime.now();

    // Ensure we have stable, device-generated submission identifiers stored
    // locally for UI (friendlyRef + submit timestamps). This must be stable
    // across retries.
    await _recordSubmitAttempt(formId: formId, attemptAt: attemptAt);

    // Reuse the originally recorded submittedAt when rebuilding the payload so
    // the device-generated friendlyRef stays stable across resubmits.
    final stableSubmittedAt = await _readStableSubmittedAt(
      formId: formId,
      fallback: attemptAt,
    );

    final payload = await HnaSubmissionPayloadBuilder.build(
      formId: formId,
      db: db,
      submittedAt: stableSubmittedAt,
      recomputeDerived: true,
    );
    if (payload == null) {
      throw PortalApiException('Form not found.');
    }

    ApmLogger.info(
      'Payload built formId=$formId schema=${HnaSubmissionPayloadBuilder.payloadSchemaVersion} assets=${_countAssets(payload)} observations=${_countList(payload, ['hna', 'observations'])} unsafeObs=${_countList(payload, ['hna', 'unsafe', 'unsafeObservations'])} attachments=${_countList(payload, ['hna', 'attachments'])}',
      category: 'HNA/Submit',
    );

    final appVersion = await appInfoService.getCurrentVersion();

    final clientSubmissionId = _tryExtractClientSubmissionId(payload);

    final requestBody = {
      'assessment': payload,
      'schemaVersion': HnaSubmissionPayloadBuilder.payloadSchemaVersion,
      ...?(clientSubmissionId == null
          ? null
          : {'clientSubmissionId': clientSubmissionId}),
      'appVersion': '${appVersion.name}+${appVersion.code}',
    };

    final editSession = await _readEditSession(formId: formId);

    Map<String, dynamic> json;
    try {
      if (editSession != null) {
        final sessionToken = (editSession['sessionToken'] ?? '')
            .toString()
            .trim();

        ApmLogger.info(
          'Submitting revision via edit session formId=$formId submissionId=${(editSession['submissionId'] ?? '').toString().trim()} editRequestId=${(editSession['editRequestId'] ?? '').toString().trim()}',
          category: 'HNA/EditSubmit',
        );

        final submissionId = await _editSessions.submitRevision(
          token: token,
          sessionToken: sessionToken,
          assessment: payload,
          schemaVersion: HnaSubmissionPayloadBuilder.payloadSchemaVersion,
          appVersion: '${appVersion.name}+${appVersion.code}',
        );

        // Shape to match the normal flow below.
        json = {'Success': true, 'Message': 'Updated', 'Data': submissionId};
      } else {
        json = await apiClient.postJson(
          '/api/hna/assessments/submit',
          bearerToken: token,
          body: requestBody,
        );
      }
    } catch (e, st) {
      ApmLogger.warning(
        'Submit request failed formId=$formId: {Error}',
        args: [e.toString()],
        category: editSession != null ? 'HNA/EditSubmit' : 'HNA/Submit',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    ApmLogger.info(
      'Submit response: success=${PortalApiClient.readResultSuccess(json)} message=${PortalApiClient.readResultMessage(json) ?? ""}',
      category: 'HNA/Submit',
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Submission failed',
      );
    }

    final submissionId = (json['Data'] ?? json['data'])?.toString();
    if (submissionId == null || submissionId.trim().isEmpty) {
      throw PortalApiException('Submission did not return an id.');
    }

    ApmLogger.info(
      'Submit accepted formId=$formId submissionId=$submissionId',
      category: 'HNA/Submit',
    );

    await _uploadAttachments(
      token: token,
      submissionId: submissionId,
      payload: payload,
    );

    await _recordSubmitSuccess(formId: formId, sentAt: DateTime.now());
    ApmLogger.info(
      'Submit complete formId=$formId submissionId=$submissionId',
      category: 'HNA/Submit',
    );
    return submissionId;
  }

  String? _tryExtractClientSubmissionId(Map<String, dynamic> payload) {
    final form = payload['form'];
    if (form is Map) {
      final uuid = (form['uuid'] ?? '').toString().trim();
      if (_looksLikeGuid(uuid)) return uuid;
    }

    final hna = payload['hna'];
    if (hna is Map) {
      final summary = hna['summary'];
      if (summary is Map) {
        final uuid = (summary['formUuid'] ?? '').toString().trim();
        if (_looksLikeGuid(uuid)) return uuid;
      }
    }

    return null;
  }

  bool _looksLikeGuid(String value) {
    if (value.isEmpty) return false;
    return _guidRegex.hasMatch(value);
  }

  Future<void> _recordSubmitAttempt({
    required int formId,
    required DateTime attemptAt,
  }) async {
    final form = await db.getForm(formId);
    if (form == null) return;

    final formData = Map<String, dynamic>.from(form['form_data'] as Map);

    final existing = formData[_submissionSummaryKey];
    final summary = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    final formUuid = (form['uuid'] ?? '').toString();
    final friendlyRef = (summary['friendlyRef'] ?? '').toString().trim();
    if (friendlyRef.isEmpty) {
      summary['friendlyRef'] = HnaSubmissionPayloadBuilder.buildFriendlyRef(
        submittedAt: attemptAt,
        formUuid: formUuid,
      );
    }

    final submittedAt = (summary['submittedAt'] ?? '').toString().trim();
    if (submittedAt.isEmpty) {
      summary['submittedAt'] = attemptAt.toIso8601String();
    }

    summary['lastAttemptAt'] = attemptAt.toIso8601String();

    formData[_submissionSummaryKey] = summary;

    await db.saveForm(
      id: formId,
      formType: (form['form_type'] ?? '').toString(),
      status: (form['status'] ?? '').toString(),
      formData: formData,
    );
  }

  Future<void> _recordSubmitSuccess({
    required int formId,
    required DateTime sentAt,
  }) async {
    final form = await db.getForm(formId);
    if (form == null) return;

    final formData = Map<String, dynamic>.from(form['form_data'] as Map);

    final existing = formData[_submissionSummaryKey];
    final summary = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    summary['sentAt'] = sentAt.toIso8601String();
    formData[_submissionSummaryKey] = summary;

    // If this was an edit-session submission, clear the session so this form
    // doesn't try to reuse a single-use token.
    formData.remove(_editSessionKey);

    await db.saveForm(
      id: formId,
      formType: (form['form_type'] ?? '').toString(),
      status: 'sent',
      formData: formData,
    );
  }

  Future<void> _uploadAttachments({
    required String token,
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final hna = payload['hna'];
    if (hna is! Map<String, dynamic>) return;

    final attachments = hna['attachments'];
    if (attachments is! List) return;

    ApmLogger.info(
      'Attachments pipeline start submissionId=$submissionId total=${attachments.length}',
      category: 'HNA/Attachments',
    );

    final missingIds = await _confirmManifest(
      token: token,
      submissionId: submissionId,
      attachments: attachments,
    );

    ApmLogger.info(
      'Manifest confirmed submissionId=$submissionId missing=${missingIds.length} sample=${missingIds.take(5).toList()}',
      category: 'HNA/Attachments',
    );

    if (missingIds.isEmpty) return;

    final toUpload = attachments
        .whereType<Map>()
        .where((a) => missingIds.contains(a['id']?.toString().trim() ?? ''))
        .toList();

    const maxParallel = 3;
    const maxRetries = 2;

    for (var i = 0; i < toUpload.length; i += maxParallel) {
      final batch = toUpload.skip(i).take(maxParallel).toList();
      await Future.wait(
        batch.map((a) async {
          final attachmentId = a['id']?.toString();
          final localPath = a['localPath']?.toString();
          final contentType = a['contentType']?.toString();

          if (attachmentId == null || attachmentId.trim().isEmpty) return;
          if (localPath == null || localPath.trim().isEmpty) return;

          final resolvedPath = await _resolveAttachmentLocalPath(localPath);
          final f = File(resolvedPath);
          if (!await f.exists()) {
            throw PortalApiException(
              'Missing attachment file: ${resolvedPath.isEmpty ? localPath : resolvedPath}',
            );
          }

          final bytes = await f.length();
          ApmLogger.debug(
            'Uploading attachment submissionId=$submissionId id=$attachmentId bytes=$bytes contentType=${contentType ?? ""}',
            category: 'HNA/Attachments',
          );

          await _uploadWithRetry(
            token: token,
            submissionId: submissionId,
            attachmentId: attachmentId,
            file: f,
            contentType: contentType,
            maxRetries: maxRetries,
          );

          ApmLogger.info(
            'Uploaded attachment submissionId=$submissionId id=$attachmentId',
            category: 'HNA/Attachments',
          );
        }),
      );
    }

    ApmLogger.info(
      'Attachments pipeline complete submissionId=$submissionId',
      category: 'HNA/Attachments',
    );
  }

  Future<String> _resolveAttachmentLocalPath(String localPath) async {
    final trimmed = localPath.trim();
    if (trimmed.isEmpty) return trimmed;

    // Legacy payloads stored absolute paths.
    if (p.isAbsolute(trimmed)) return trimmed;

    // URLs / web blob refs should not be treated as local files.
    if (trimmed.contains('://') || trimmed.startsWith('data:')) return trimmed;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, trimmed);
    } catch (_) {
      // Best-effort fallback.
      return trimmed;
    }
  }

  Future<Set<String>> _confirmManifest({
    required String token,
    required String submissionId,
    required List<dynamic> attachments,
  }) async {
    final manifest = attachments
        .whereType<Map>()
        .map((a) {
          final attachmentId = a['id']?.toString();
          final localPath = a['localPath']?.toString();
          final contentType = a['contentType']?.toString();
          final fileName = localPath?.split(Platform.pathSeparator).last;

          if (attachmentId == null || attachmentId.trim().isEmpty) {
            return null;
          }

          return {
            'attachmentId': attachmentId,
            'contentType': contentType,
            'fileName': fileName,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (manifest.isEmpty) return {};

    final json = await apiClient.postJson(
      '/api/hna/assessments/$submissionId/attachments/manifest',
      bearerToken: token,
      body: {'attachments': manifest},
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ??
            'Attachment manifest confirmation failed',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) return {};

    final missing =
        data['missingAttachmentIds'] ??
        data['missingAttachmentIds'.toLowerCase()];
    if (missing is! List) return {};

    return missing.map((e) => e.toString()).toSet();
  }

  Future<void> _uploadWithRetry({
    required String token,
    required String submissionId,
    required String attachmentId,
    required File file,
    String? contentType,
    required int maxRetries,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        await _uploadSingleAttachment(
          token: token,
          submissionId: submissionId,
          attachmentId: attachmentId,
          file: file,
          contentType: contentType,
        );
        return;
      } catch (e) {
        ApmLogger.warning(
          'Upload attempt failed submissionId=$submissionId attachmentId=$attachmentId attempt=$attempt error={Error}',
          args: [e.toString()],
          category: 'HNA/Attachments',
          error: e,
        );
        if (attempt >= maxRetries) rethrow;
        final delayMs = 500 * (attempt + 1);
        await Future.delayed(Duration(milliseconds: delayMs));
        attempt += 1;
      }
    }
  }

  Future<void> _uploadSingleAttachment({
    required String token,
    required String submissionId,
    required String attachmentId,
    required File file,
    String? contentType,
  }) async {
    final base = ApiConfig.portalBaseUrl.trim();
    if (base.isEmpty) {
      throw PortalApiException('PORTAL_BASE_URL is not configured.');
    }

    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;

    final uri = Uri.parse(
      '$normalizedBase/api/hna/assessments/$submissionId/attachments/$attachmentId/upload',
    );

    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer ${token.trim()}';
    req.headers['Accept'] = 'application/json';

    final fileLength = await file.length();
    final stream = http.ByteStream(file.openRead());

    req.files.add(
      http.MultipartFile(
        'file',
        stream,
        fileLength,
        filename: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : '$attachmentId.img',
        contentType: contentType == null || contentType.trim().isEmpty
            ? null
            : _tryParseMediaType(contentType),
      ),
    );

    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PortalApiException(
        body.isEmpty ? 'Attachment upload failed' : body,
        statusCode: resp.statusCode,
      );
    }
  }

  MediaType? _tryParseMediaType(String v) {
    final parts = v.split('/');
    if (parts.length != 2) return null;
    final type = parts[0].trim();
    final sub = parts[1].trim();
    if (type.isEmpty || sub.isEmpty) return null;
    return MediaType(type, sub);
  }

  int _countList(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
        continue;
      }
      if (current is Map) {
        current = current[key];
        continue;
      }
      return 0;
    }
    return current is List ? current.length : 0;
  }

  String _countAssets(Map<String, dynamic> payload) {
    final hna = payload['hna'];
    if (hna is! Map) return '0';
    final assets = hna['assets'];
    if (assets is! Map) return '0';

    int total = 0;
    for (final v in assets.values) {
      if (v is List) total += v.length;
    }
    return total.toString();
  }
}
