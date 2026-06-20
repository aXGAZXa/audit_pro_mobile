import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/auth/auth_storage.dart';

import 'apm_log_entry.dart';
import 'apm_logger.dart';

/// Pushes locally-persisted warning/error/fatal logs (table `apm_logs`) to the
/// server so they appear in the portal. Reuses [PortalApiClient] + the mobile
/// JWT from [AuthTokenStore], mirroring the generic submit/CR/HNA flows.
///
/// Design rules (these must NOT break the app):
/// - Fully best-effort: never throws into callers; offline / no-token / HTTP
///   failure is a silent no-op that simply retries on the next trigger.
/// - NEVER calls [ApmLogger.error]/[ApmLogger.fatal] (or anything that does) —
///   an upload failure must not generate a new error log (that would recurse and
///   could grow the queue without bound). Diagnostics use debug/info only.
/// - Concurrency-guarded: overlapping flushes are coalesced.
/// - Reads only UN-uploaded rows and marks them uploaded after a 200.
class ApmDeviceLogUploadService {
  ApmDeviceLogUploadService({
    AuthTokenStore? tokenStore,
    AppInfoService? appInfoService,
    AuthStorage? authStorage,
    PortalApiClient? apiClient,
    this.batchSize = 50,
    this.debounce = const Duration(seconds: 8),
  })  : _tokenStore = tokenStore ?? AuthTokenStore(),
        _appInfoService = appInfoService ?? AppInfoService(),
        _authStorage = authStorage ?? AuthStorage(),
        _apiClient =
            apiClient ?? PortalApiClient(baseUrl: ApiConfig.portalBaseUrl);

  final AuthTokenStore _tokenStore;
  final AppInfoService _appInfoService;
  final AuthStorage _authStorage;
  final PortalApiClient _apiClient;

  /// Max rows POSTed per request. The flush loops until the queue is drained.
  final int batchSize;

  /// Debounce window for [requestFlush] (post-error trigger coalescing).
  final Duration debounce;

  /// FIXED device-log batch endpoint (see server contract).
  static const String uploadPath = '/api/apm/device-logs';

  bool _flushing = false;
  Timer? _debounceTimer;

  // Cached best-effort context; resolved once, reused across flushes.
  String? _appVersion;
  String? _deviceId;
  bool _contextResolved = false;

  /// Registers this service as the logger's flush trigger and performs the
  /// initial start-up flush (fire-and-forget). Safe to call once after auth is
  /// available. Never throws.
  void start() {
    if (kIsWeb) return;
    ApmLogger.onFlushRequested = requestFlush;
    unawaited(flushNow());
  }

  /// Debounced flush request — called (indirectly) after each error/fatal log.
  /// Coalesces a burst of errors into a single delayed flush.
  void requestFlush() {
    if (kIsWeb) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(flushNow());
    });
  }

  /// Drains the local un-uploaded queue to the server. Best-effort and
  /// non-throwing. Returns the number of rows successfully uploaded.
  Future<int> flushNow() async {
    if (kIsWeb) return 0;
    if (_flushing) return 0;
    _flushing = true;
    var uploaded = 0;
    try {
      final token = await _tokenStore.getAccessToken();
      if (token == null || token.trim().isEmpty) return 0;

      if (_apiClient.baseUrl.trim().isEmpty) return 0;

      await _ensureContext();

      // Loop in batches until the queue is empty or a batch fails. A failed
      // batch leaves its (and later) rows un-uploaded for the next trigger.
      while (true) {
        final batch = await ApmLogger.readUnuploaded(limit: batchSize);
        if (batch.isEmpty) break;

        final body = _buildBody(batch);

        try {
          await _apiClient.postJson(uploadPath, body: body, bearerToken: token);
        } catch (e) {
          // No-op on failure: do NOT log via ApmLogger.error/fatal (recursion).
          if (kDebugMode) {
            ApmLogger.debug(
              'Device-log upload batch failed (will retry): {Error}',
              args: [e.toString()],
              category: 'DeviceLogs/Upload',
            );
          }
          break;
        }

        await ApmLogger.markUploaded(batch.map((e) => e.id).toList());
        uploaded += batch.length;

        // If the server returned fewer than a full batch, we've likely drained
        // the backlog; the next loop's readUnuploaded confirms (empty -> break).
        if (batch.length < batchSize) break;
      }
    } catch (e) {
      // Never allow the uploader to crash the app or generate error logs.
      if (kDebugMode) {
        ApmLogger.debug(
          'Device-log flush aborted: {Error}',
          args: [e.toString()],
          category: 'DeviceLogs/Upload',
        );
      }
    } finally {
      _flushing = false;
    }
    return uploaded;
  }

  Future<void> _ensureContext() async {
    if (_contextResolved) return;
    try {
      final v = await _appInfoService.getCurrentVersion();
      _appVersion = v.code > 0 ? '${v.name}+${v.code}' : v.name;
    } catch (_) {}
    try {
      _deviceId = await _authStorage.getOrCreateDeviceId();
    } catch (_) {}
    _contextResolved = true;
  }

  /// Builds the batch request body matching the server contract exactly.
  Map<String, dynamic> _buildBody(List<ApmLogEntry> batch) {
    final platform = _safePlatform();
    final osVersion = _safeOsVersion();

    return <String, dynamic>{
      'logs': batch.map((e) {
        // category carries the APM/<Area> context; surface it as extraJson too
        // so the server can index/group without parsing the message.
        final extra = <String, dynamic>{
          if (e.category != null) 'category': e.category,
          'logId': e.id,
        };

        return <String, dynamic>{
          'message': e.message,
          'level': e.level.name, // warning | error | fatal
          'category': e.category,
          'occurredAtUtc': e.createdUtcIso,
          'exceptionType': null,
          'exceptionMessage': e.error,
          'stackTrace': e.stackTrace,
          'appVersion': _appVersion,
          'platform': platform,
          'deviceId': _deviceId,
          'deviceModel': null,
          'osVersion': osVersion,
          'extraJson': jsonEncode(extra),
        };
      }).toList(),
    };
  }

  static String? _safePlatform() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return null;
    }
  }

  static String? _safeOsVersion() {
    try {
      final v = Platform.operatingSystemVersion.trim();
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }
}
