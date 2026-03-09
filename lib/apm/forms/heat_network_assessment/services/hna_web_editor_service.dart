import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../services/portal_api_client.dart';

class HnaWebEditorService {
  HnaWebEditorService({required this.apiClient});

  final PortalApiClient apiClient;

  static const String ticketHeader = 'X-GTAPP-EDITOR-TICKET';

  Uri _uri(String path) {
    final trimmedBase = apiClient.baseUrl.trim();
    if (trimmedBase.isEmpty) {
      throw PortalApiException(
        'PORTAL_BASE_URL is not configured. Provide --dart-define=PORTAL_BASE_URL=https://...'
        ' when running/building the app.',
      );
    }

    final base = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

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
    bool generatePdf = true,
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
      body: {'payloadJson': payloadJson, 'generatePdf': generatePdf},
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

  Future<List<int>> getAttachmentBytes({
    required String ticket,
    required String attachmentId,
  }) async {
    return apiClient.getBytes(
      '/api/editor/hna/attachments/$attachmentId/content',
      headers: {ticketHeader: ticket},
    );
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required String ticket,
    required String attachmentId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final uri = _uri('/api/editor/hna/attachments/$attachmentId/upload');

    final request = http.MultipartRequest('POST', uri);
    request.headers[ticketHeader] = ticket;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );

    final streamed = await apiClient.httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          PortalApiClient.readResultMessage(json) ??
          response.reasonPhrase ??
          'Upload failed';
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Upload failed',
        statusCode: response.statusCode,
      );
    }

    return json;
  }
}
