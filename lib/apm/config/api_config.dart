/// Backend integration configuration.
///
/// Configure at build/run time with:
/// `--dart-define=PORTAL_BASE_URL=https://your-portal-host`
///
/// If `PORTAL_BASE_URL` is not provided, this falls back to
/// `APM_API_BASE_URL` so submission flows stay aligned with the rest of
/// the app's API host configuration.
class ApiConfig {
  // String.fromEnvironment must be evaluated in a const context (it is resolved
  // at compile time from --dart-define); trim/compare afterwards. Using it in a
  // non-const `final` throws "can only be used as a const constructor" at runtime
  // on the web build.
  static const String _explicitPortalBaseUrl =
      String.fromEnvironment('PORTAL_BASE_URL', defaultValue: '');
  static const String _legacyApiBaseUrl =
      String.fromEnvironment('APM_API_BASE_URL', defaultValue: '');

  static String get portalBaseUrl {
    final explicit = _explicitPortalBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit;

    final legacy = _legacyApiBaseUrl.trim();
    if (legacy.isNotEmpty) return legacy;

    return 'https://portal.audit-pro.co.uk/';
  }
}
