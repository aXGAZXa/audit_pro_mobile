import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';

class FormsStartEditSessionResponse {
  const FormsStartEditSessionResponse({
    required this.sessionToken,
    required this.expiresAtUtc,
    required this.submissionId,
    required this.editRequestId,
  });

  final String sessionToken;
  final DateTime? expiresAtUtc;
  final String submissionId;
  final String editRequestId;

  static String _readStringAny(Map raw, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static DateTime? _readDateTimeAny(Map raw, List<String> keys) {
    final s = _readStringAny(raw, keys);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory FormsStartEditSessionResponse.fromJson(Map raw) {
    return FormsStartEditSessionResponse(
      sessionToken: _readStringAny(raw, ['sessionToken', 'SessionToken']),
      expiresAtUtc: _readDateTimeAny(raw, ['expiresAtUtc', 'ExpiresAtUtc']),
      submissionId: _readStringAny(raw, ['submissionId', 'SubmissionId']),
      editRequestId: _readStringAny(raw, ['editRequestId', 'EditRequestId']),
    );
  }
}

class FormsEditSessionSnapshot {
  const FormsEditSessionSnapshot({
    required this.formType,
    required this.submissionId,
    required this.submittedAtUtc,
    required this.schemaVersion,
    required this.appVersion,
    required this.formPayload,
  });

  final String formType;
  final String submissionId;
  final DateTime? submittedAtUtc;
  final int? schemaVersion;
  final String appVersion;
  final Map<String, dynamic> formPayload;

  static String _readStringAny(Map raw, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static int? _readIntAny(Map raw, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v is int) return v;
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _readDateTimeAny(Map raw, List<String> keys) {
    final s = _readStringAny(raw, keys);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static Map<String, dynamic> _readMapAny(Map raw, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return const <String, dynamic>{};
  }

  factory FormsEditSessionSnapshot.fromJson(Map raw) {
    return FormsEditSessionSnapshot(
      formType: _readStringAny(raw, ['formType', 'FormType']),
      submissionId: _readStringAny(raw, ['submissionId', 'SubmissionId']),
      submittedAtUtc: _readDateTimeAny(raw, [
        'submittedAtUtc',
        'SubmittedAtUtc',
      ]),
      schemaVersion: _readIntAny(raw, ['schemaVersion', 'SchemaVersion']),
      appVersion: _readStringAny(raw, ['appVersion', 'AppVersion']),
      formPayload: _readMapAny(raw, ['formPayload', 'FormPayload']),
    );
  }
}

class FormsEditSessionsService {
  FormsEditSessionsService({PortalApiClient? apiClient})
    : apiClient =
          apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final PortalApiClient apiClient;

  Future<FormsStartEditSessionResponse> start({
    required String token,
    required String editRequestId,
  }) async {
    final json = await apiClient.postJson(
      '/api/mobile/edit-sessions/start',
      bearerToken: token,
      body: {'editRequestId': editRequestId},
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ??
            'Failed to start edit session',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) {
      throw PortalApiException('Invalid start edit session response.');
    }

    final dto = FormsStartEditSessionResponse.fromJson(data);
    if (dto.sessionToken.trim().isEmpty) {
      throw PortalApiException('Edit session did not return a token.');
    }

    return dto;
  }

  Future<FormsEditSessionSnapshot> snapshot({
    required String token,
    required String sessionToken,
  }) async {
    final json = await apiClient.postJson(
      '/api/mobile/edit-sessions/snapshot',
      bearerToken: token,
      body: {'sessionToken': sessionToken},
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Failed to load snapshot',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) {
      throw PortalApiException('Invalid snapshot response.');
    }

    return FormsEditSessionSnapshot.fromJson(data);
  }

  Future<String> submitRevision({
    required String token,
    required String sessionToken,
    required Map<String, dynamic> formPayload,
    required int schemaVersion,
    required String appVersion,
  }) async {
    final json = await apiClient.postJson(
      '/api/mobile/edit-sessions/submit-revision',
      bearerToken: token,
      body: {
        'sessionToken': sessionToken,
        'formPayload': formPayload,
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
      },
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Revision submit failed',
      );
    }

    final submissionId =
        (json['Data'] ?? json['data'])?.toString().trim() ?? '';
    if (submissionId.isEmpty) {
      throw PortalApiException(
        'Revision submit did not return a submission id.',
      );
    }

    return submissionId;
  }
}
