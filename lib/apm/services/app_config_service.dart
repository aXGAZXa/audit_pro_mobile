import 'dart:convert';

import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

/// Fetches the calling app's DELIVERED app config and surfaces its
/// `AppDefinition.theme` so the app can re-theme from a builder-authored theme
/// (theme slice — Step 4).
///
/// The endpoint (`GET /api/forms/app/config`) is JWT-scoped: the server filters
/// by the signed `app_id` claim carried in the mobile token, so the app does NOT
/// send an appId. Same auth/transport as the form-definition catalog — the
/// mobile_app bearer token from [AuthTokenStore] and [ApiConfig.portalBaseUrl]
/// via [PortalApiClient]. Tolerates the `{data:...}`/`{Data:...}` (`Result<T>`)
/// envelope and camel/Pascal keys.
///
/// FAIL-OPEN by design: any error / no token / no published config returns null
/// (logged via [ApmLogger], never throws), so a bad or missing theme can never
/// block the app — it just falls back to the baseline look.
class AppConfigService {
  AppConfigService({AuthTokenStore? tokenStore, PortalApiClient? apiClient})
    : tokenStore = tokenStore ?? AuthTokenStore(),
      apiClient =
          apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final AuthTokenStore tokenStore;
  final PortalApiClient apiClient;

  static const String _configPath = '/api/forms/app/config';

  /// Returns the delivered [AppDefinition] (theme + navigation + …), or null if
  /// none is delivered or any error occurs. NEVER throws (fail-open) — a bad or
  /// missing config can never block the app.
  Future<gtmobile.AppDefinition?> fetchAppDefinition() async {
    try {
      final token = await tokenStore.getAccessToken();
      if (token == null || token.trim().isEmpty) {
        // Not signed in yet — no delivered config to fetch.
        return null;
      }

      final json = await apiClient.getJson(_configPath, bearerToken: token);

      final row = _unwrapMap(json);
      if (row == null) {
        // OK-null payload: no published config for this app.
        return null;
      }

      final appConfigJson = _readAppConfigJson(row);
      if (appConfigJson == null || appConfigJson.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(appConfigJson);
      if (decoded is! Map) return null;

      return gtmobile.AppDefinition.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (e, st) {
      ApmLogger.warning(
        'App config fetch failed baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'APM/AppConfig',
        error: e,
        stackTrace: st,
      );
      // Fail-open: a bad/missing config must never block the app.
      return null;
    }
  }

  /// Convenience: the delivered theme only. Delegates to [fetchAppDefinition].
  Future<gtmobile.GTAppThemeConfig?> fetchAppTheme() async =>
      (await fetchAppDefinition())?.theme;

  /// Unwraps the single-row payload from a `{ data|Data: {...} }` (`Result<T>`)
  /// envelope. Returns null when the envelope's data is null (OK-null) or when
  /// the body is otherwise not a config object.
  Map<String, dynamic>? _unwrapMap(Map<String, dynamic> json) {
    if (json.containsKey('data') || json.containsKey('Data')) {
      final data = json['data'] ?? json['Data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v));
      }
      // Explicit null data (OK-null) — no delivered config.
      return null;
    }
    // Bare object fallback (no envelope).
    return json;
  }

  String? _readAppConfigJson(Map<String, dynamic> row) {
    final v = row['appConfigJson'] ?? row['AppConfigJson'];
    return v?.toString();
  }
}
