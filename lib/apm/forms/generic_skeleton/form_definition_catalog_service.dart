import 'dart:convert';

import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';

/// Lightweight summary of a server-published form definition.
///
/// Mirrors the server `FormDefinitionSummary` returned by
/// `GET /api/forms/definitions` (the list endpoint never carries the heavy
/// `definitionJson`). Tolerant of both camelCase and PascalCase keys.
class FormDefinitionSummary {
  const FormDefinitionSummary({
    required this.id,
    required this.formType,
    required this.version,
    required this.displayName,
    required this.status,
  });

  final String id;
  final String formType;
  final String version;
  final String displayName;
  final String status;

  factory FormDefinitionSummary.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) {
          final s = value.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return fallback;
    }

    final formType = pick(['formType', 'FormType']);
    final displayName = pick(
      ['displayName', 'DisplayName', 'title', 'Title'],
      fallback: formType.isNotEmpty ? formType : 'Untitled form',
    );

    return FormDefinitionSummary(
      id: pick(['id', 'Id']),
      formType: formType,
      version: pick(['version', 'Version']),
      displayName: displayName,
      status: pick(['status', 'Status']),
    );
  }
}

/// Fetches server-published form definitions and parses them into the SAME
/// [gtmobile.FormPackage] shape the bundled skeleton asset uses, so a fetched
/// definition renders through the identical generic runtime path.
///
/// NON-DISRUPTIVE: brand-new read-only path. Authenticates exactly like
/// [GenericFormSubmissionService] — the mobile_app bearer token from
/// [AuthTokenStore] and [ApiConfig.portalBaseUrl] via [PortalApiClient]. Does
/// NOT touch live CR/HNA flows.
class FormDefinitionCatalogService {
  FormDefinitionCatalogService({
    AuthTokenStore? tokenStore,
    PortalApiClient? apiClient,
  })  : tokenStore = tokenStore ?? AuthTokenStore(),
        apiClient =
            apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final AuthTokenStore tokenStore;
  final PortalApiClient apiClient;

  static const String _listPath = '/api/forms/definitions';
  static const String _latestPath = '/api/forms/definitions/latest';
  static const String _appListPath = '/api/forms/app/definitions';

  Future<String> _requireToken() async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw PortalApiException('You are not signed in.');
    }
    return token;
  }

  /// Lists published form definitions (summaries; no definitionJson).
  Future<List<FormDefinitionSummary>> listDefinitions() async {
    final token = await _requireToken();

    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson(_listPath, bearerToken: token);
    } catch (e, st) {
      ApmLogger.warning(
        'Form definition list fetch failed baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Catalog',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    final items = _unwrapList(json);
    return items
        .whereType<Map>()
        .map((m) => FormDefinitionSummary.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  /// Lists ONLY the calling app's published form definitions (summaries; no
  /// definitionJson), via `GET /api/forms/app/definitions`.
  ///
  /// The endpoint is JWT-scoped: the server filters by the signed `app_id`
  /// claim carried in the mobile token, so the app does NOT send an appId.
  /// Same auth/transport as [listDefinitions]; tolerates the
  /// `{data:...}`/`{Data:...}` (`Result<T>`) envelope.
  Future<List<FormDefinitionSummary>> listAppDefinitions() async {
    final token = await _requireToken();

    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson(_appListPath, bearerToken: token);
    } catch (e, st) {
      ApmLogger.warning(
        'App form definition list fetch failed baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Catalog',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    final items = _unwrapList(json);
    return items
        .whereType<Map>()
        .map((m) => FormDefinitionSummary.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  /// Fetches a single full definition by [id] (via
  /// `GET /api/forms/definitions/{id}`) or the latest published one for a
  /// [formType] (via `GET /api/forms/definitions/latest?formType=X`), then
  /// parses its `definitionJson` into a [gtmobile.FormPackage] — identical to
  /// how `SkeletonDemoScreen` parses the bundled asset.
  ///
  /// Exactly one of [id] / [formType] must be provided.
  Future<gtmobile.FormPackage> fetchDefinition({
    String? id,
    String? formType,
  }) async {
    final hasId = id != null && id.trim().isNotEmpty;
    final hasType = formType != null && formType.trim().isNotEmpty;
    if (hasId == hasType) {
      throw ArgumentError(
        'fetchDefinition requires exactly one of id or formType.',
      );
    }

    final token = await _requireToken();
    final path = hasId
        ? '$_listPath/${Uri.encodeComponent(id.trim())}'
        : '$_latestPath?formType=${Uri.encodeQueryComponent(formType!.trim())}';

    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson(path, bearerToken: token);
    } catch (e, st) {
      ApmLogger.warning(
        'Form definition fetch failed path=$path baseUrl=${apiClient.baseUrl}: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Catalog',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    final row = _unwrapMap(json);
    final definitionJson = _readDefinitionJson(row);
    if (definitionJson == null || definitionJson.trim().isEmpty) {
      throw PortalApiException(
        'The published definition did not include definitionJson.',
      );
    }

    final decoded = _decodeDefinition(definitionJson);
    // Same call as SkeletonDemoScreen: relies on registerFormComponents()
    // having run at app startup (see main.dart).
    return gtmobile.FormPackage.fromJson(decoded);
  }

  /// Unwraps a list payload from a bare array body or a `{ data|Data: [...] }`
  /// envelope.
  List<dynamic> _unwrapList(Map<String, dynamic> json) {
    final data = json['data'] ?? json['Data'];
    if (data is List) return data;
    // Some envelopes nest under `items`/`results`.
    for (final key in ['items', 'Items', 'results', 'Results']) {
      final v = json[key];
      if (v is List) return v;
    }
    if (data is Map) {
      for (final key in ['items', 'Items', 'results', 'Results']) {
        final v = data[key];
        if (v is List) return v;
      }
    }
    return const [];
  }

  /// Unwraps a single-row payload from a bare object or a `{ data|Data: {...} }`
  /// envelope.
  Map<String, dynamic> _unwrapMap(Map<String, dynamic> json) {
    final data = json['data'] ?? json['Data'];
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return json;
  }

  String? _readDefinitionJson(Map<String, dynamic> row) {
    final v = row['definitionJson'] ?? row['DefinitionJson'];
    return v?.toString();
  }

  /// `definitionJson` is itself a JSON string (a serialized FormPackage). Decode
  /// it to the map FormPackage.fromJson expects.
  Map<String, dynamic> _decodeDefinition(String definitionJson) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(definitionJson);
    } catch (_) {
      throw PortalApiException('definitionJson was not valid JSON.');
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    throw PortalApiException('definitionJson was not a JSON object.');
  }
}
