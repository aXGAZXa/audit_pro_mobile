import 'dart:convert';

import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.schemaVersion,
    required this.revision,
    required this.displayName,
    required this.status,
  });

  final String id;
  final String formType;
  final String version;

  /// Per-form version (major / breaking line). Mirrors the .NET
  /// `FormDefinitionSummary.SchemaVersion`. Defaults to 0 when absent.
  final int schemaVersion;

  /// Per-form revision (safe-change counter within a schema line). Mirrors the
  /// .NET `FormDefinitionSummary.Revision`. Defaults to 1 when absent.
  final int revision;

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

    int pickInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          final parsed = int.tryParse(value.toString().trim());
          if (parsed != null) return parsed;
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
      schemaVersion: pickInt(['schemaVersion', 'SchemaVersion'], fallback: 0),
      revision: pickInt(['revision', 'Revision'], fallback: 1),
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

  /// EA3: read a SHARED-LIBRARY container's body by id (+ optional pinned version). The .NET endpoint
  /// does NOT exist yet (see the report) — when it lands it must return the library container's
  /// `BodyJson` (AppDefinition-shaped: sections[]/forms[]/collections[]) so [gtmobile.SharedLibrary]
  /// can parse it. Until then this fetch fails-open (null) and fill resolves nothing, gracefully.
  static const String _sharedLibraryPath = '/api/forms/shared-library';

  /// Offline cache key prefix for a fetched shared-library body (keyed by container@version).
  static const String _sharedLibCachePrefix = 'shared_library_v1::';

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
  ///
  /// [dev] selects the DEV working copy (APM's Developer page) instead of the latest live (Home). The
  /// server GATES it on the token's `is_developer` claim, so a non-developer always gets live.
  Future<List<FormDefinitionSummary>> listAppDefinitions({bool dev = false}) async {
    final token = await _requireToken();

    final path = dev ? '$_appListPath?dev=true' : _appListPath;
    Map<String, dynamic> json;
    try {
      json = await apiClient.getJson(path, bearerToken: token);
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

    // ENGINE GUARD (Tier 1): if this form uses any control this app build can't
    // render (authored against a newer engine), refuse to open it rather than
    // crash on parse or silently drop a control — which for a gated/safety form
    // (e.g. HNA's unsafe escalation) would drop the gate. Throws
    // FormEngineTooOldException, surfaced to the user as "update the app".
    gtmobile.FormEngineGuard.assertRenderable(decoded);

    // Same call as SkeletonDemoScreen: relies on registerFormComponents()
    // having run at app startup (see main.dart).
    final package = gtmobile.FormPackage.fromJson(decoded);

    // EA3: fetch + cache the form's pinned shared library ALONGSIDE the definition, so the FILL walk
    // can resolve a `sectionReference` offline (EA4). The owning app's `SharedLibraryContainerId` +
    // `SharedLibraryVersion` are read from the delivery row (when the .NET delivery starts carrying
    // them — see report). No coords / fetch fails / endpoint absent → package returned unchanged
    // (fail-open): shared sections then render nothing, gracefully.
    final libContainerId = _readSharedLibraryContainerId(row);
    if (libContainerId == null || libContainerId.isEmpty) {
      return package;
    }
    final libVersion = _readSharedLibraryVersion(row);
    final library = await _fetchSharedLibrary(
      containerId: libContainerId,
      version: libVersion,
      token: token,
    );
    return library == null ? package : package.copyWith(sharedLibrary: library);
  }

  /// EA3: fetch a shared-library container by id (+ optional pinned version), parse it into a
  /// [gtmobile.SharedLibrary], and cache the raw body for offline use. Fail-open: any error / absent
  /// endpoint → falls back to the offline cache, else null. NEVER throws (a missing library must
  /// never break opening a form).
  Future<gtmobile.SharedLibrary?> _fetchSharedLibrary({
    required String containerId,
    int? version,
    required String token,
  }) async {
    final cacheKey =
        '$_sharedLibCachePrefix$containerId@${version?.toString() ?? 'live'}';
    final path = version != null
        ? '$_sharedLibraryPath/${Uri.encodeComponent(containerId)}?version=$version'
        : '$_sharedLibraryPath/${Uri.encodeComponent(containerId)}';

    try {
      final json = await apiClient.getJson(path, bearerToken: token);
      final row = _unwrapMap(json);
      final bodyJson = _readSharedLibraryBodyJson(row);
      if (bodyJson == null || bodyJson.trim().isEmpty) {
        return _loadCachedSharedLibrary(cacheKey);
      }
      await _cacheSharedLibrary(cacheKey, bodyJson);
      return _parseSharedLibrary(bodyJson);
    } catch (e, st) {
      ApmLogger.warning(
        'EA3 shared-library fetch failed container=$containerId; using offline cache: {Error}',
        args: [e.toString()],
        category: 'GenericForms/SharedLibrary',
        error: e,
        stackTrace: st,
      );
      return _loadCachedSharedLibrary(cacheKey);
    }
  }

  gtmobile.SharedLibrary? _parseSharedLibrary(String bodyJson) {
    try {
      final decoded = jsonDecode(bodyJson);
      if (decoded is! Map) return null;
      return gtmobile.SharedLibrary.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSharedLibrary(String cacheKey, String bodyJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, bodyJson);
    } catch (_) {
      // Caching is best-effort; a failed write must never break delivery.
    }
  }

  Future<gtmobile.SharedLibrary?> _loadCachedSharedLibrary(
      String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached == null || cached.trim().isEmpty) return null;
      return _parseSharedLibrary(cached);
    } catch (_) {
      return null;
    }
  }

  String? _readSharedLibraryContainerId(Map<String, dynamic> row) {
    final v = row['sharedLibraryContainerId'] ??
        row['SharedLibraryContainerId'] ??
        row['sharedLibraryId'] ??
        row['SharedLibraryId'];
    return v?.toString().trim();
  }

  int? _readSharedLibraryVersion(Map<String, dynamic> row) {
    final v = row['sharedLibraryVersion'] ?? row['SharedLibraryVersion'];
    if (v == null) return null;
    if (v is int) return v;
    // "schemaVersion.revision" or "N" → the schema line head (mirrors .NET EA5 pin parse).
    final head = v.toString().split('.').first.trim();
    return int.tryParse(head);
  }

  String? _readSharedLibraryBodyJson(Map<String, dynamic> row) {
    final v = row['bodyJson'] ??
        row['BodyJson'] ??
        row['sharedLibraryJson'] ??
        row['SharedLibraryJson'];
    return v?.toString();
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
