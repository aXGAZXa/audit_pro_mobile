/// Backend integration configuration.
///
/// Configure at build/run time with:
/// `--dart-define=PORTAL_BASE_URL=https://your-portal-host`
class ApiConfig {
  static const String portalBaseUrl = String.fromEnvironment(
    'PORTAL_BASE_URL',
    defaultValue: 'https://buildingservices-portal.co.uk/',
  );
}
