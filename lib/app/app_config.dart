import 'package:flutter/foundation.dart';

/// Central app configuration for API connectivity.
///
/// - Web: uses the current origin (same as the portal hosting /apm-web).
/// - Mobile/desktop: defaults to the live admin portal.
/// - Override via build-time define: --dart-define=APM_API_BASE_URL=http://...
class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'APM_API_BASE_URL',
    defaultValue: '',
  );

  static const String _defaultLivePortalBaseUrl =
      'https://portal.audit-pro.co.uk';

  static const String _mobileAuthApiKey = String.fromEnvironment(
    'APM_MOBILE_AUTH_API_KEY',
    defaultValue: '',
  );

  static const String _definesSource = String.fromEnvironment(
    'APM_DEFINES_SOURCE',
    defaultValue: '',
  );

  static String get apiBaseUrlOverride => _apiBaseUrlOverride.trim();

  static String get apiBaseUrl {
    final override = apiBaseUrlOverride;
    if (override.isNotEmpty) {
      return override.endsWith('/')
          ? override.substring(0, override.length - 1)
          : override;
    }

    if (kIsWeb) {
      return Uri.base.origin;
    }

    // Default to the live portal when not explicitly overridden.
    // For local dev against a local portal API, use:
    // --dart-define-from-file=env/auditpromobile.local.env
    // with APM_API_BASE_URL=http://10.0.2.2:5168 (Android emulator) or http://localhost:5168.
    return _defaultLivePortalBaseUrl;
  }

  static String get mobileAuthApiKey => _mobileAuthApiKey.trim();

  static String get definesSource => _definesSource.trim();

  static Uri apiUri(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API path cannot be empty');
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }

    final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return Uri.parse('$apiBaseUrl$withLeadingSlash');
  }
}
