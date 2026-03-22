import 'dart:convert';

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_payload_builder.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/services/forms_edit_sessions_service.dart';
import 'package:audit_pro_mobile/apm/forms/services/form_response_attachment_sync_service.dart';
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

  final FormsEditSessionsService _editSessions = FormsEditSessionsService();
  late final FormResponseAttachmentSyncService _attachmentSync =
      FormResponseAttachmentSyncService(apiClient: apiClient);

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
    final formType = _readCanonicalFormType(payload);

    final requestBody = {
      'formType': formType,
      'payloadJson': jsonEncode(payload),
      'schemaVersion': HnaSubmissionPayloadBuilder.payloadSchemaVersion,
      ...?(clientSubmissionId == null
          ? null
          : {'clientResponseId': clientSubmissionId}),
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
          formPayload: payload,
          schemaVersion: HnaSubmissionPayloadBuilder.payloadSchemaVersion,
          appVersion: '${appVersion.name}+${appVersion.code}',
        );

        // Shape to match the normal flow below.
        json = {'Success': true, 'Message': 'Updated', 'Data': submissionId};
      } else {
        json = await apiClient.postJson(
          '/api/forms/submit',
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

    final submissionId = _readSubmissionId(json);
    if (submissionId == null || submissionId.trim().isEmpty) {
      throw PortalApiException('Submission did not return an id.');
    }

    ApmLogger.info(
      'Submit accepted formId=$formId submissionId=$submissionId',
      category: 'HNA/Submit',
    );

    final attachments = _readAttachments(payload);
    if (attachments.isNotEmpty) {
      await _attachmentSync.syncDirectUploads(
        bearerToken: token,
        responseId: submissionId,
        attachments: attachments,
        endpoints: FormResponseAttachmentEndpoints.forHnaAssessments(),
      );
    }

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

  List<Map<String, dynamic>> _readAttachments(Map<String, dynamic> payload) {
    final hna = payload['hna'];
    if (hna is! Map) return const [];

    final attachments = hna['attachments'];
    if (attachments is! List) return const [];

    return attachments
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  String _readCanonicalFormType(Map<String, dynamic> payload) {
    final form = payload['form'];
    if (form is Map) {
      final value = (form['formType'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return kHeatNetworkAssessmentFormType;
  }

  String? _readSubmissionId(Map<String, dynamic> json) {
    final data = json['Data'] ?? json['data'];
    if (data is Map) {
      final responseId = data['responseId'] ?? data['ResponseId'];
      final value = responseId?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final direct = data?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

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
