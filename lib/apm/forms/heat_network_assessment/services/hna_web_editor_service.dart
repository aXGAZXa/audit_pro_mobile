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

  /// GENERIC web editor: presign + PUT a newly picked image to R2 (ticket-authed),
  /// returning the attachment manifest record `{id, key, contentType, fileName,
  /// sizeBytes}` to record in the envelope's `attachments[]` and append to the
  /// question answer. The server derives the key from the submission (never
  /// trusts the client). [attachmentId] is a NEW client-minted id.
  Future<Map<String, dynamic>> uploadGenericAttachment({
    required String ticket,
    required String attachmentId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final targetJson = await apiClient.postJson(
      '/api/editor/attachments/upload-targets',
      headers: {ticketHeader: ticket},
      body: {
        'items': [
          {
            'attachmentId': attachmentId,
            'contentType': contentType,
            'fileName': fileName,
            'sizeBytes': bytes.length,
          },
        ],
      },
    );

    if (!PortalApiClient.readResultSuccess(targetJson)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(targetJson) ??
            'Failed to get upload target',
      );
    }

    final data = PortalApiClient.readResultData<Map<String, dynamic>>(
      targetJson,
    );
    final items = data == null ? null : data['items'];
    if (items is! List || items.isEmpty || items.first is! Map) {
      throw PortalApiException('Malformed upload target response');
    }

    final target = Map<String, dynamic>.from(items.first as Map);
    final uploadUrl = (target['uploadUrl'] ?? '').toString().trim();
    final key = (target['key'] ?? '').toString().trim();
    if (uploadUrl.isEmpty || key.isEmpty) {
      throw PortalApiException('Missing upload URL or key');
    }

    final requiredHeaders = <String, String>{};
    final rawHeaders = target['requiredHeaders'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        requiredHeaders[k.toString()] = v.toString();
      });
    }
    requiredHeaders.putIfAbsent('Content-Type', () => contentType);

    final putRequest = http.Request('PUT', Uri.parse(uploadUrl));
    putRequest.headers.addAll(requiredHeaders);
    putRequest.bodyBytes = bytes;

    final putResponse = await apiClient.httpClient.send(putRequest);
    final putBody = await putResponse.stream.bytesToString();
    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw PortalApiException(
        putBody.isEmpty ? 'Direct upload failed' : putBody,
        statusCode: putResponse.statusCode,
      );
    }

    return <String, dynamic>{
      'id': attachmentId,
      'key': key,
      'contentType': contentType,
      'fileName': fileName,
      'sizeBytes': bytes.length,
    };
  }

  /// GENERIC web editor: best-effort delete of an attachment's R2 object
  /// (ticket-authed). The envelope reference is removed by the editor's save
  /// reconciliation; this only reclaims storage. Swallows nothing — the caller
  /// decides whether a failure should block the optimistic UI removal.
  Future<void> deleteGenericAttachment({
    required String ticket,
    required String attachmentId,
  }) async {
    final json = await apiClient.deleteJson(
      '/api/editor/attachments/$attachmentId',
      headers: {ticketHeader: ticket},
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      throw PortalApiException(
        PortalApiClient.readResultMessage(json) ?? 'Delete failed',
      );
    }
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
