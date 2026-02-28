import 'dart:convert';

import '../../../services/portal_api_client.dart';

class HnaWebEditorService {
  HnaWebEditorService({required this.apiClient});

  final PortalApiClient apiClient;

  static const String ticketHeader = 'X-GTAPP-EDITOR-TICKET';

  Future<Map<String, dynamic>> getSession({required String ticket}) async {
    final json = await apiClient.getJson(
      '/api/editor/hna/session',
      headers: {ticketHeader: ticket},
    );

    final data = PortalApiClient.readResultData<Map<String, dynamic>>(json);
    if (data == null) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Failed to load session',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> getSubmission({required String ticket}) async {
    final json = await apiClient.getJson(
      '/api/editor/hna/submission',
      headers: {ticketHeader: ticket},
    );

    final data = PortalApiClient.readResultData<Map<String, dynamic>>(json);
    if (data == null) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Failed to load submission',
      );
    }

    return data;
  }

  Future<void> updateSubmission({
    required String ticket,
    required String payloadJson,
  }) async {
    // Client-side sanity check so we can give a clean error message.
    try {
      jsonDecode(payloadJson);
    } catch (_) {
      throw PortalApiException('PayloadJson is not valid JSON.');
    }

    final json = await apiClient.putJson(
      '/api/editor/hna/submission',
      headers: {ticketHeader: ticket},
      body: {'payloadJson': payloadJson},
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Save failed',
      );
    }
  }

  Future<List<String>> getClients({required String ticket}) async {
    final json = await apiClient.getJson(
      '/api/editor/hna/clients',
      headers: {ticketHeader: ticket},
    );

    final data = PortalApiClient.readResultData<List<dynamic>>(json);
    if (data == null) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Failed to load clients',
      );
    }

    final out = <String>[];
    for (final item in data) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final name = (map['name'] ?? map['Name'])?.toString().trim();
        if (name != null && name.isNotEmpty) out.add(name);
      }
    }

    return out.toSet().toList()..sort();
  }
}
