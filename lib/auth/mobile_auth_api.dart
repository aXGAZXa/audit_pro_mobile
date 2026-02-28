import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/app_config.dart';
import 'mobile_auth_models.dart';

class MobileAuthApi {
  static const _tenantSelectionRequiredMessage = 'tenant_selection_required';

  Map<String, String> _preAuthHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final apiKey = AppConfig.mobileAuthApiKey;
    if (apiKey.isNotEmpty) {
      headers['X-API-KEY'] = apiKey;
    }
    return headers;
  }

  Future<ApiResult<void>> requestOtp({
    required String email,
    String? tenantId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/request-otp'),
      headers: _preAuthHeaders(),
      body: jsonEncode({'email': email, 'tenantId': tenantId}),
    );

    final json = _decodeJson(res);
    final result = ApiResult.fromJson<void>(json);

    if (res.statusCode == 409 &&
        result.message == _tenantSelectionRequiredMessage) {
      throw const ApiTenantSelectionRequired();
    }

    return result;
  }

  Future<ApiResult<String>> verifyOtp({
    required String email,
    required String code,
    String? tenantId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/verify-otp'),
      headers: _preAuthHeaders(),
      body: jsonEncode({'email': email, 'code': code, 'tenantId': tenantId}),
    );

    final json = _decodeJson(res);
    final result = ApiResult.fromJson<String>(
      json,
      parseData: (d) => d?.toString(),
    );

    if (res.statusCode == 409 &&
        result.message == _tenantSelectionRequiredMessage) {
      throw const ApiTenantSelectionRequired();
    }

    return result;
  }

  Future<ApiResult<List<MobileTenantOption>>> tenantOptions({
    required String email,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/tenant-options'),
      headers: _preAuthHeaders(),
      body: jsonEncode({'email': email}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<List<MobileTenantOption>>(
      json,
      parseData: (d) {
        if (d is! List) return const [];
        return d
            .whereType<Map>()
            .map(
              (m) => MobileTenantOption.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
      },
    );
  }

  Future<ApiResult<String>> refresh({required String token}) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/refresh'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'token': token}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<String>(json, parseData: (d) => d?.toString());
  }

  Future<ApiResult<void>> lockTenant({
    required String token,
    required String tenantId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/lock-tenant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'tenantId': tenantId}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<void>(json);
  }

  Future<ApiResult<String>> switchTenant({
    required String token,
    required String tenantId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/switch-tenant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'tenantId': tenantId}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<String>(json, parseData: (d) => d?.toString());
  }

  Future<ApiResult<void>> requestPlatformAccess({
    required String token,
    required String deviceId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/request-platform-access'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'deviceId': deviceId}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<void>(json);
  }

  Future<ApiResult<PlatformAccessStatus>> platformAccessStatus({
    required String token,
    required String deviceId,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/mobile/auth/platform-access-status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'deviceId': deviceId}),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<PlatformAccessStatus>(
      json,
      parseData: (d) {
        if (d is! Map) return null;
        return PlatformAccessStatus.fromJson(Map<String, dynamic>.from(d));
      },
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': body,
        'data': null,
        'statusCode': response.statusCode,
      };
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final json = Map<String, dynamic>.from(decoded);
      json.putIfAbsent('statusCode', () => response.statusCode);
      return json;
    }

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': body,
      'data': decoded,
      'statusCode': response.statusCode,
    };
  }
}
