import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'auth_storage.dart';
import 'mobile_auth_models.dart';
import '../logging/apm_logger.dart';

class AuthState {
  AuthState({
    required this.email,
    required this.token,
    required this.platformToken,
    required this.platformBiometricsEnabled,
    required this.tenantId,
    required this.tenantName,
  });

  final String email;
  final String token;
  final String? platformToken;
  final bool platformBiometricsEnabled;
  final String? tenantId;
  final String? tenantName;
}

class AuthSession {
  AuthSession({AuthStorage? storage}) : _storage = storage ?? AuthStorage();

  final AuthStorage _storage;
  final ValueNotifier<AuthState?> state = ValueNotifier<AuthState?>(null);

  Future<void> load() async {
    String? token;
    String? platformToken;
    bool platformBiometricsEnabled = false;
    String? email;
    String? tenantId;
    String? tenantName;

    try {
      token = await _storage.readToken();
      platformToken = await _storage.readPlatformToken();
      platformBiometricsEnabled = await _storage
          .readPlatformBiometricsEnabled();
      email = await _storage.readEmail();
      tenantId = await _storage.readTenantId();
      tenantName = await _storage.readTenantName();
    } catch (e, st) {
      ApmLogger.warning(
        'Auth load failed: {Error}',
        args: [e.toString()],
        category: 'AuthSession',
        error: e,
        stackTrace: st,
      );
      state.value = null;
      return;
    }

    ApmLogger.info(
      'Auth loaded (hasToken: {HasToken}, hasEmail: {HasEmail}, hasTenantId: {HasTenantId}, hasTenantName: {HasTenantName})',
      args: [
        (token ?? '').trim().isNotEmpty,
        (email ?? '').trim().isNotEmpty,
        (tenantId ?? '').trim().isNotEmpty,
        (tenantName ?? '').trim().isNotEmpty,
      ],
      category: 'AuthSession',
    );

    if (token == null || email == null) {
      state.value = null;
      return;
    }

    state.value = AuthState(
      email: email,
      token: token,
      platformToken: (platformToken ?? '').trim().isEmpty
          ? null
          : platformToken,
      platformBiometricsEnabled: platformBiometricsEnabled,
      tenantId: tenantId,
      tenantName: tenantName,
    );
  }

  Future<void> signIn({
    required String email,
    required String token,
    String? tenantId,
    String? tenantName,
  }) async {
    await _storage.writeEmail(email);
    await _storage.writeToken(token);
    await _storage.writeTenantId(tenantId);
    await _storage.writeTenantName(tenantName);

    state.value = AuthState(
      email: email,
      token: token,
      platformToken: state.value?.platformToken,
      platformBiometricsEnabled:
          state.value?.platformBiometricsEnabled ?? false,
      tenantId: tenantId,
      tenantName: tenantName,
    );
  }

  Future<void> setPlatformToken(String? token) async {
    await _storage.writePlatformToken(token);
    final current = state.value;
    if (current == null) return;

    final normalized = (token ?? '').trim();
    final cleared = normalized.isEmpty;
    if (cleared) {
      await _storage.writePlatformBiometricsEnabled(false);
    }
    state.value = AuthState(
      email: current.email,
      token: current.token,
      platformToken: normalized.isEmpty ? null : normalized,
      platformBiometricsEnabled: cleared
          ? false
          : current.platformBiometricsEnabled,
      tenantId: current.tenantId,
      tenantName: current.tenantName,
    );
  }

  Future<void> setPlatformBiometricsEnabled(bool enabled) async {
    await _storage.writePlatformBiometricsEnabled(enabled);
    final current = state.value;
    if (current == null) return;

    state.value = AuthState(
      email: current.email,
      token: current.token,
      platformToken: current.platformToken,
      platformBiometricsEnabled: enabled,
      tenantId: current.tenantId,
      tenantName: current.tenantName,
    );
  }

  Future<void> updateToken(String token) async {
    final current = state.value;
    if (current == null) return;

    final normalized = token.trim();
    if (normalized.isEmpty) return;

    await _storage.writeToken(normalized);

    state.value = AuthState(
      email: current.email,
      token: normalized,
      platformToken: current.platformToken,
      platformBiometricsEnabled: current.platformBiometricsEnabled,
      tenantId: current.tenantId,
      tenantName: current.tenantName,
    );
  }

  Future<void> signOut() async {
    await _storage.clear();
    state.value = null;
  }

  Future<void> cacheTenantOptions({
    required String email,
    required List<MobileTenantOption> options,
  }) async {
    final json = jsonEncode(
      options
          .map((o) => {'tenantId': o.tenantId, 'tenantName': o.tenantName})
          .toList(),
    );
    await _storage.writeTenantOptionsCache(email: email, json: json);
  }

  Future<List<MobileTenantOption>> readCachedTenantOptions({
    required String email,
  }) async {
    final json = await _storage.readTenantOptionsCacheJson(email: email);
    if (json == null || json.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((m) => MobileTenantOption.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
