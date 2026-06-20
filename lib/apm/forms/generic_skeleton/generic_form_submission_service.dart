import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;
import 'package:uuid/uuid.dart';

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'generic_form_attachment_upload_service.dart';

/// Submits a generic forms-unification envelope to the new (breakable) generic
/// receive endpoint. NON-DISRUPTIVE: this is a brand-new path used only by the
/// dev/debug skeleton entry point; it does NOT touch the live CR/HNA submit
/// flows, repositories, or local DB.
///
/// Mirrors the auth + base-URL pattern used by [CrSubmissionService]: the
/// mobile_app bearer token from [AuthTokenStore] and [ApiConfig.portalBaseUrl]
/// via [PortalApiClient].
class GenericFormSubmissionService {
  GenericFormSubmissionService({
    AuthTokenStore? tokenStore,
    AppInfoService? appInfoService,
    PortalApiClient? apiClient,
    GenericFormAttachmentUploadService? attachmentUploadService,
    Uuid? uuid,
  })  : tokenStore = tokenStore ?? AuthTokenStore(),
        appInfoService = appInfoService ?? AppInfoService(),
        apiClient =
            apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl),
        _injectedUploadService = attachmentUploadService,
        _uuid = uuid ?? const Uuid();

  final AuthTokenStore tokenStore;
  final AppInfoService appInfoService;
  final PortalApiClient apiClient;
  final Uuid _uuid;

  final GenericFormAttachmentUploadService? _injectedUploadService;

  /// Uploads generic form images to R2 before submit. Reuses THIS service's
  /// [apiClient] (same base URL + http client) unless one was injected for tests.
  late final GenericFormAttachmentUploadService attachmentUploadService =
      _injectedUploadService ??
          GenericFormAttachmentUploadService(apiClient: apiClient);

  /// FIXED generic submission endpoint (forms-unification contract).
  static const String submitPath = '/api/mobile/generic-forms/submit';

  /// Builds the generic submission envelope from a [FormState.toJson] map and
  /// POSTs it. Returns the server-issued `responseId`.
  ///
  /// [formType] is the stable form-type slug (e.g. `skeleton_demo`).
  /// [formDefinitionId] is the FormDefinition's id.
  /// [formDefinitionVersion] is the FormDefinition's integer schema version.
  /// [responseJson] is `FormState.toJson()` (answers keyed by element uuid +
  /// a collections map — empty for the collection-free skeleton).
  ///
  /// [package] is the rendered [gtmobile.FormPackage]. When supplied, every
  /// image-question answer is resolved to its captured [gtmobile.GTImage], each
  /// image is uploaded straight to R2 (presigned PUT), and the resulting R2 keys
  /// are placed in the envelope's `attachments[]` (path-only delivery). When
  /// omitted, or when the form has no image questions, `attachments[]` is empty.
  ///
  /// Throws [GenericAttachmentUploadException] (and aborts the submit, keeping
  /// the local draft/images) if any photo upload fails — images are never
  /// silently dropped.
  Future<String> submit({
    required String formType,
    required String formDefinitionId,
    required int formDefinitionVersion,
    required Map<String, dynamic> responseJson,
    gtmobile.FormPackage? package,
  }) async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw PortalApiException('You are not signed in.');
    }

    final appVersion = await appInfoService.getCurrentVersion();
    final clientResponseId = _uuid.v4();

    // STEP 1+2: upload captured images straight to R2 and gather their keys.
    // (No-op when there are no image questions / no captured images.)
    final attachments = await _uploadAttachments(
      token: token,
      clientResponseId: clientResponseId,
      package: package,
      responseJson: responseJson,
    );

    final envelope = <String, dynamic>{
      'formType': formType,
      'formDefinitionId': formDefinitionId,
      'formDefinitionVersion': formDefinitionVersion,
      'clientResponseId': clientResponseId,
      'submittedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'appVersion': '${appVersion.name}+${appVersion.code}',
      'response': responseJson,
      'attachments': attachments,
    };

    Map<String, dynamic> json;
    try {
      json = await apiClient.postJson(
        submitPath,
        bearerToken: token,
        body: envelope,
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Generic skeleton submit failed formType=$formType '
        'clientResponseId=$clientResponseId baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Submit',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    final responseId = _readResponseId(json);
    if (responseId == null || responseId.trim().isEmpty) {
      throw PortalApiException('Submission did not return a responseId.');
    }

    ApmLogger.info(
      'Generic skeleton submit complete formType=$formType responseId=$responseId',
      category: 'GenericForms/Submit',
    );

    return responseId;
  }

  /// Collects this submission's image-question images, uploads each to R2, and
  /// returns the envelope `attachments[]` list (path-only objects). Returns an
  /// empty list when [package] is null or the form has no captured images.
  Future<List<Map<String, dynamic>>> _uploadAttachments({
    required String token,
    required String clientResponseId,
    required gtmobile.FormPackage? package,
    required Map<String, dynamic> responseJson,
  }) async {
    if (package == null) return <Map<String, dynamic>>[];

    final pending = await attachmentUploadService.collectPendingAttachments(
      package: package,
      responseJson: responseJson,
    );
    if (pending.isEmpty) return <Map<String, dynamic>>[];

    final uploaded = await attachmentUploadService.upload(
      bearerToken: token,
      clientResponseId: clientResponseId,
      pending: pending,
    );

    return uploaded.map((a) => a.toEnvelopeJson()).toList();
  }

  /// Reads `responseId` from the response. Tolerates either a bare
  /// `{ "responseId": "..." }` body (the fixed contract) or the portal's
  /// `{ Data: { responseId } }` envelope shape.
  String? _readResponseId(Map<String, dynamic> json) {
    final direct = json['responseId'] ?? json['ResponseId'];
    final directValue = direct?.toString().trim();
    if (directValue != null && directValue.isNotEmpty) return directValue;

    final data = json['Data'] ?? json['data'];
    if (data is Map) {
      final nested = data['responseId'] ?? data['ResponseId'];
      final nestedValue = nested?.toString().trim();
      if (nestedValue != null && nestedValue.isNotEmpty) return nestedValue;
    }

    return null;
  }
}
