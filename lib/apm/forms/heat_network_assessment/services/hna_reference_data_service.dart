import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/jwt_debug.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

class HnaReferenceDataService {
  HnaReferenceDataService({
    required this.tokenStore,
    required this.apiClient,
    DatabaseHelper? db,
  }) : db = db ?? DatabaseHelper.instance;

  final AuthTokenStore tokenStore;
  final PortalApiClient apiClient;
  final DatabaseHelper db;

  Future<void> syncClientsIfSignedIn() async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      ApmLogger.info(
        'Clients sync skipped: no token',
        category: 'HNA/ReferenceData',
      );
      return;
    }

    ApmLogger.info(
      'Clients sync start baseUrl=${apiClient.baseUrl} jwt=${maskToken(token)} ${describeJwtForLogs(token)}',
      category: 'HNA/ReferenceData',
    );

    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson('/api/hna/clients', bearerToken: token);
    } catch (e, st) {
      ApmLogger.warning(
        'Clients sync request failed: {Error}',
        args: [e.toString()],
        category: 'HNA/ReferenceData',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    ApmLogger.info(
      'Clients sync response: success=${PortalApiClient.readResultSuccess(json)} message=${PortalApiClient.readResultMessage(json) ?? ""}',
      category: 'HNA/ReferenceData',
    );
    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Failed to load clients',
      );
    }

    final data = (json['Data'] ?? json['data']);
    if (data is! List) {
      ApmLogger.warning(
        'Clients sync: unexpected data type ({Type})',
        args: [data.runtimeType.toString()],
        category: 'HNA/ReferenceData',
      );
      return;
    }

    final names = <String>[];
    for (final item in data) {
      if (item is Map) {
        final n = item['Name'] ?? item['name'];
        if (n != null) names.add(n.toString());
      }
    }

    ApmLogger.info(
      'Clients sync parsed: count=${names.length} sample=${names.take(3).toList()}',
      category: 'HNA/ReferenceData',
    );

    await db.replaceClients(names);

    ApmLogger.info(
      'Clients sync saved: count=${names.length}',
      category: 'HNA/ReferenceData',
    );
  }
}
