import 'dart:convert';

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/condition_report_definition.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_payload_builder.dart';
import 'package:audit_pro_mobile/apm/forms/services/form_response_attachment_sync_service.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

class CrSubmissionService {
  CrSubmissionService({
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
  late final FormResponseAttachmentSyncService _attachmentSync =
      FormResponseAttachmentSyncService(apiClient: apiClient);

  static const String _submissionSummaryKey = 'submissionSummary';

  Future<String?> submitForm({required int formId}) async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw PortalApiException('You are not signed in.');
    }

    final attemptAt = DateTime.now().toUtc();
    await _recordSubmitAttempt(formId: formId, attemptAt: attemptAt);

    final payload = await CrSubmissionPayloadBuilder.build(
      formId: formId,
      db: db,
      submittedAt: attemptAt,
    );
    if (payload == null) {
      throw PortalApiException('Form not found.');
    }

    final appVersion = await appInfoService.getCurrentVersion();

    final requestBody = {
      'formType': kConditionReportFormType,
      'payloadJson': jsonEncode(payload),
      'schemaVersion': CrSubmissionPayloadBuilder.payloadSchemaVersion,
      'clientResponseId': _tryReadClientResponseId(payload),
      'appVersion': '${appVersion.name}+${appVersion.code}',
    };

    Map<String, dynamic> json;
    try {
      json = await apiClient.postJson(
        '/api/forms/submit',
        bearerToken: token,
        body: requestBody,
      );
    } catch (e, st) {
      ApmLogger.warning(
        'CR submit request failed formId=$formId baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'CR/Submit',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Submission failed',
      );
    }

    final responseId = _readSubmissionId(json);
    if (responseId == null || responseId.trim().isEmpty) {
      throw PortalApiException('Submission did not return an id.');
    }

    final attachments = _readAttachments(payload);
    if (attachments.isNotEmpty) {
      await _attachmentSync.syncDirectUploads(
        bearerToken: token,
        responseId: responseId,
        attachments: attachments,
      );
    }

    await _recordSubmitSuccess(formId: formId, sentAt: DateTime.now().toUtc());

    ApmLogger.info(
      'CR submit complete formId=$formId responseId=$responseId',
      category: 'CR/Submit',
    );

    return responseId;
  }

  String? _tryReadClientResponseId(Map<String, dynamic> payload) {
    final form = payload['form'];
    if (form is! Map) return null;

    final uuid = (form['uuid'] ?? '').toString().trim();
    if (uuid.isEmpty) return null;

    return uuid;
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

  List<Map<String, dynamic>> _readAttachments(Map<String, dynamic> payload) {
    final cr = payload['conditionReport'];
    if (cr is! Map) return const [];

    final attachments = cr['attachments'];
    if (attachments is! List) return const [];

    return attachments
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
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

    await db.saveForm(
      id: formId,
      formType: (form['form_type'] ?? '').toString(),
      status: 'sent',
      formData: formData,
    );
  }
}
