import 'dart:convert';

class JwtPayload {
  JwtPayload(this.claims);

  final Map<String, Object?> claims;

  static JwtPayload? tryParse(String? token) {
    final t = (token ?? '').trim();
    if (t.isEmpty) return null;

    final parts = t.split('.');
    if (parts.length < 2) return null;

    try {
      final payloadB64 = parts[1];
      final jsonBytes = base64Url.decode(_normalizeBase64Url(payloadB64));
      final decoded = jsonDecode(utf8.decode(jsonBytes));
      if (decoded is! Map) return null;
      return JwtPayload(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  String get displayName {
    final v = claims['display_name'];
    return (v ?? '').toString();
  }

  String? get tenantId {
    final v = claims['gtapp_tenant_id'] ?? claims['tenantId'];
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  String? get tenantName {
    final v = claims['gtapp_tenant_name'] ?? claims['tenantName'];
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  bool get canAccessPlatformLogin {
    final v = claims['can_access_platform_login'];
    if (v is bool) return v;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static String _normalizeBase64Url(String input) {
    final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 0:
        return normalized;
      case 2:
        return '$normalized==';
      case 3:
        return '$normalized=';
      default:
        return normalized;
    }
  }
}
