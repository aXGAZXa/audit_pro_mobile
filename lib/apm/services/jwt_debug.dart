import 'dart:convert';

/// Best-effort JWT parsing for diagnostics.
///
/// This does NOT validate signatures.
Map<String, dynamic>? tryDecodeJwtPayload(String? token) {
  if (token == null) return null;
  final t = token.trim();
  if (t.isEmpty) return null;

  final parts = t.split('.');
  if (parts.length < 2) return null;

  try {
    final payload = _decodeBase64UrlJson(parts[1]);
    if (payload is Map<String, dynamic>) return payload;
    return null;
  } catch (_) {
    return null;
  }
}

String maskToken(String? token, {int head = 6, int tail = 6}) {
  if (token == null) return '';
  final t = token.trim();
  if (t.isEmpty) return '';

  if (t.length <= head + tail + 3) {
    return '*' * t.length;
  }

  return '${t.substring(0, head)}...${t.substring(t.length - tail)}';
}

String describeJwtForLogs(String? token) {
  final claims = tryDecodeJwtPayload(token);
  if (claims == null) return 'jwt=unparsed';

  final iss = claims['iss']?.toString();
  final aud = claims['aud']?.toString();
  final expRaw = claims['exp'];

  final tokenType = (claims['token_type'] ?? claims['tokenType'])?.toString();
  final tenantId = (claims['gtapp_tenant_id'] ?? claims['tenantId'])
      ?.toString();
  final apAppUserId = (claims['ap_app_user_id'] ?? claims['apAppUserId'])
      ?.toString();
  final legacyAppUserId = (claims['ml_app_user_id'])?.toString();

  final parts = <String>[];
  if (iss != null && iss.trim().isNotEmpty) {
    parts.add('iss=$iss');
  }
  if (aud != null && aud.trim().isNotEmpty) {
    parts.add('aud=$aud');
  }
  final expEpochSeconds = _tryParseEpochSeconds(expRaw);
  if (expEpochSeconds != null) {
    final expLocal = DateTime.fromMillisecondsSinceEpoch(
      expEpochSeconds * 1000,
      isUtc: true,
    ).toLocal();
    parts.add('exp=${expLocal.toIso8601String()}');
  }
  if (tokenType != null && tokenType.trim().isNotEmpty) {
    parts.add('token_type=$tokenType');
  }
  if (tenantId != null && tenantId.trim().isNotEmpty) {
    parts.add('gtapp_tenant_id=$tenantId');
  }
  if (apAppUserId != null && apAppUserId.trim().isNotEmpty) {
    parts.add('ap_app_user_id=$apAppUserId');
  }
  if (legacyAppUserId != null && legacyAppUserId.trim().isNotEmpty) {
    parts.add('ml_app_user_id=$legacyAppUserId');
  }

  return parts.isEmpty ? 'jwt=parsed(no relevant claims)' : parts.join(' ');
}

int? _tryParseEpochSeconds(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

Object? _decodeBase64UrlJson(String part) {
  var payload = part.replaceAll('-', '+').replaceAll('_', '/');
  switch (payload.length % 4) {
    case 2:
      payload += '==';
      break;
    case 3:
      payload += '=';
      break;
  }

  final bytes = base64Decode(payload);
  final decoded = utf8.decode(bytes);
  return jsonDecode(decoded);
}
