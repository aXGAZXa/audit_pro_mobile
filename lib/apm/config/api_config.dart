/// Backend integration configuration.
///
/// Configure at build/run time with:
/// `--dart-define=PORTAL_BASE_URL=https://your-portal-host`
///
/// If `PORTAL_BASE_URL` is not provided, this falls back to
/// `APM_API_BASE_URL` so submission flows stay aligned with the rest of
/// the app's API host configuration.
class ApiConfig {
  static String get portalBaseUrl {
    final explicit = String.fromEnvironment(
      'PORTAL_BASE_URL',
      defaultValue: '',
    ).trim();
    if (explicit.isNotEmpty) return explicit;

    final legacy = String.fromEnvironment(
      'APM_API_BASE_URL',
      defaultValue: '',
    ).trim();
    if (legacy.isNotEmpty) return legacy;

    return 'https://portal.audit-pro.co.uk/';
  }
}
