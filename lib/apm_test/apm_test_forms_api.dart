import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/app_config.dart';
import '../auth/mobile_auth_models.dart';
import 'apm_test_models.dart';

class ApmTestFormsApi {
  Future<ApiResult<ApmTestFormSubmission>> submit({
    required String token,
    required String formKey,
    required String clientSubmissionId,
    required String payloadJson,
  }) async {
    final res = await http.post(
      AppConfig.apiUri('/api/apm-test/forms/submit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'formKey': formKey,
        'clientSubmissionId': clientSubmissionId,
        'payloadJson': payloadJson,
      }),
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<ApmTestFormSubmission>(
      json,
      parseData: (d) {
        if (d is! Map) return null;
        return ApmTestFormSubmission.fromJson(Map<String, dynamic>.from(d));
      },
    );
  }

  Future<ApiResult<List<ApmTestFormSubmission>>> listSubmissions({
    required String token,
    int take = 200,
  }) async {
    final res = await http.get(
      AppConfig.apiUri('/api/apm-test/forms/submissions?take=$take'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final json = _decodeJson(res);
    return ApiResult.fromJson<List<ApmTestFormSubmission>>(
      json,
      parseData: (d) {
        if (d is! List) return const [];
        return d
            .whereType<Map>()
            .map(
              (m) =>
                  ApmTestFormSubmission.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
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
      };
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': body,
      'data': decoded,
    };
  }
}
