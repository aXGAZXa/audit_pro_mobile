import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

class HnaPendingEditRequest {
  const HnaPendingEditRequest({
    required this.editRequestId,
    required this.submissionId,
    required this.tenantId,
    required this.tenantName,
    required this.managerName,
    required this.message,
    required this.requestedAtUtc,
  });

  final String editRequestId;
  final String submissionId;
  final String tenantId;
  final String tenantName;
  final String managerName;
  final String message;
  final DateTime? requestedAtUtc;

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

  factory HnaPendingEditRequest.fromJson(Map raw) {
    final editRequestId = _readStringAny(raw, [
      'editRequestId',
      'EditRequestId',
    ]);
    final submissionId = _readStringAny(raw, ['submissionId', 'SubmissionId']);
    final tenantId = _readStringAny(raw, ['tenantId', 'TenantId']);
    final tenantName = _readStringAny(raw, ['tenantName', 'TenantName']);
    final managerName = _readStringAny(raw, [
      'managerName',
      'ManagerName',
      'requestedByName',
      'RequestedByName',
    ]);
    final message = _readStringAny(raw, [
      'message',
      'Message',
      'messageToUser',
      'MessageToUser',
    ]);
    final requestedAtUtc = _readDateTimeAny(raw, [
      'requestedAtUtc',
      'RequestedAtUtc',
      'requestedAt',
      'RequestedAt',
    ]);

    return HnaPendingEditRequest(
      editRequestId: editRequestId,
      submissionId: submissionId,
      tenantId: tenantId,
      tenantName: tenantName,
      managerName: managerName,
      message: message,
      requestedAtUtc: requestedAtUtc,
    );
  }
}

class HnaEditRequestsService {
  HnaEditRequestsService({PortalApiClient? apiClient})
    : apiClient =
          apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final PortalApiClient apiClient;

  Future<List<HnaPendingEditRequest>> getPending({
    required String token,
  }) async {
    const path = '/api/mobile/hna/edit-requests/pending';

    ApmLogger.debug(
      'Checking pending edit requests (baseUrl: {BaseUrl}, tokenLen: {TokenLen})',
      args: [ApiConfig.portalBaseUrl, token.length],
      category: 'HNA/EditRequests',
    );

    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson(path, bearerToken: token);
    } catch (e, st) {
      // Avoid double warning logs; UI handles the warning/toast.
      ApmLogger.debug(
        'Pending edit requests request failed: {Error}',
        args: [e.toString()],
        category: 'HNA/EditRequests',
      );
      ApmLogger.debug(
        'Pending edit requests request failed stack: {Stack}',
        args: [st.toString()],
        category: 'HNA/EditRequests',
      );
      rethrow;
    }

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ??
            'Failed to load edit requests',
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! List) return const [];

    final items = data
        .whereType<Map>()
        .map((m) => HnaPendingEditRequest.fromJson(m))
        .where((r) => r.editRequestId.isNotEmpty)
        .toList();

    ApmLogger.debug(
      'Pending edit requests returned {Count} item(s): {Ids}',
      args: [
        items.length,
        items
            .take(5)
            .map((r) => r.editRequestId)
            .where((id) => id.trim().isNotEmpty)
            .join(', '),
      ],
      category: 'HNA/EditRequests',
    );

    return items;
  }
}
