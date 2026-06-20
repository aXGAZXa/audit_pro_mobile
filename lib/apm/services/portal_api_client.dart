import 'dart:convert';

import 'package:http/http.dart' as http;

class PortalApiException implements Exception {
  PortalApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'PortalApiException: $message'
      : 'PortalApiException($statusCode): $message';
}

class PortalApiClient {
  PortalApiClient({required this.baseUrl, http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client httpClient;

  Uri _uri(String path) {
    final trimmedBase = baseUrl.trim();
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

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);

    final reqHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    if (headers != null) {
      reqHeaders.addAll(headers);
    }

    final response = await httpClient.post(
      uri,
      headers: reqHeaders,
      body: jsonEncode(body),
    );

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _readMessage(json) ?? response.reasonPhrase ?? 'Request failed';
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    return json;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);

    final reqHeaders = <String, String>{
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    if (headers != null) {
      reqHeaders.addAll(headers);
    }

    final response = await httpClient.get(uri, headers: reqHeaders);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _readMessage(json) ?? response.reasonPhrase ?? 'Request failed';
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    return json;
  }

  Future<List<int>> getBytes(
    String path, {
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);

    final reqHeaders = <String, String>{
      if (headers != null) ...headers,
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    final response = await httpClient.get(uri, headers: reqHeaders);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message;
      try {
        final decoded = jsonDecode(response.body);
        message = decoded is Map<String, dynamic>
            ? (_readMessage(decoded) ??
                  response.reasonPhrase ??
                  'Request failed')
            : (response.reasonPhrase ?? 'Request failed');
      } catch (_) {
        message = response.body.isNotEmpty
            ? response.body
            : (response.reasonPhrase ?? 'Request failed');
      }
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);

    final reqHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    if (headers != null) {
      reqHeaders.addAll(headers);
    }

    final response = await httpClient.put(
      uri,
      headers: reqHeaders,
      body: jsonEncode(body),
    );

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _readMessage(json) ?? response.reasonPhrase ?? 'Request failed';
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    return json;
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);

    final reqHeaders = <String, String>{
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    if (headers != null) {
      reqHeaders.addAll(headers);
    }

    final response = await httpClient.delete(uri, headers: reqHeaders);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _readMessage(json) ?? response.reasonPhrase ?? 'Request failed';
      throw PortalApiException(message, statusCode: response.statusCode);
    }

    return json;
  }

  static bool? _readSuccess(Map<String, dynamic> json) {
    final v = json['Success'] ?? json['success'];
    return v is bool ? v : null;
  }

  static String? _readMessage(Map<String, dynamic> json) {
    final v = json['Message'] ?? json['message'];
    return v is String ? v : null;
  }

  static T? readResultData<T>(Map<String, dynamic> json) {
    final success = _readSuccess(json);
    if (success == false) return null;
    final data = json['Data'] ?? json['data'];
    if (data is T) return data;
    return null;
  }

  static String? readResultMessage(Map<String, dynamic> json) =>
      _readMessage(json);

  static bool readResultSuccess(Map<String, dynamic> json) =>
      _readSuccess(json) ?? false;
}
