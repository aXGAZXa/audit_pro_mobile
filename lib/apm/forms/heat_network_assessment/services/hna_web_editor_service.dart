import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/portal_api_client.dart';

class FormWebEditorService {
  FormWebEditorService({required this.apiClient});

  final PortalApiClient apiClient;

  static const String ticketHeader = 'X-GTAPP-EDITOR-TICKET';

  Future<Map<String, dynamic>> getSession({required String ticket}) async {
    final json = await apiClient.getJson(
      '/api/editor/session',
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
      '/api/editor/submission',
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
      '/api/editor/submission',
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
      '/api/editor/clients',
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
      '/api/editor/attachments/$attachmentId/content',
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
    final targetJson = await apiClient.postJson(
      '/api/editor/attachments/$attachmentId/upload-target',
      headers: {ticketHeader: ticket},
      body: {
        'fileName': fileName,
        'contentType': contentType,
        'fileSize': bytes.length,
      },
    );

    if (!PortalApiClient.readResultSuccess(targetJson)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(targetJson) ??
            'Failed to get upload target',
      );
    }

    final targetData = PortalApiClient.readResultData<Map<String, dynamic>>(
      targetJson,
    );
    if (targetData == null) {
      throw PortalApiException('Malformed upload target response');
    }

    final uploadUrl = (targetData['uploadUrl'] ?? '').toString().trim();
    final uploadContentType = (targetData['contentType'] ?? contentType)
        .toString()
        .trim();
    if (uploadUrl.isEmpty) {
      throw PortalApiException('Missing upload URL');
    }

    final putRequest = http.Request('PUT', Uri.parse(uploadUrl));
    putRequest.headers['Content-Type'] = uploadContentType;
    putRequest.bodyBytes = bytes;

    final putResponse = await apiClient.httpClient.send(putRequest);
    final putBody = await putResponse.stream.bytesToString();
    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw PortalApiException(
        putBody.isEmpty ? 'Direct upload failed' : putBody,
        statusCode: putResponse.statusCode,
      );
    }

    final finalizeJson = await apiClient.postJson(
      '/api/editor/attachments/$attachmentId/finalize',
      headers: {ticketHeader: ticket},
      body: {
        'fileName': fileName,
        'contentType': uploadContentType,
        'fileSize': bytes.length,
      },
    );

    if (!PortalApiClient.readResultSuccess(finalizeJson)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(finalizeJson) ??
            'Upload finalize failed',
      );
    }

    return finalizeJson;
  }
}
