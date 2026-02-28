import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthStorage {
  static const _tokenKey = 'apm.jwt';
  static const _platformTokenKey = 'apm.platform.jwt';
  static const _platformBiometricsEnabledKey = 'apm.platform.bioEnabled';
  static const _emailKey = 'apm.email';
  static const _tenantIdKey = 'apm.tenantId';
  static const _tenantNameKey = 'apm.tenantName';

  static const _deviceIdKey = 'apm.deviceId';
  static const _platformAccessRequestedAtUtcPrefix =
      'apm.platformAccessRequestedAtUtc.';

  static const _tenantOptionsEmailKey = 'apm.tenantOptions.email';
  static const _tenantOptionsJsonKey = 'apm.tenantOptions.json';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Uuid _uuid = Uuid();

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String? _normalizeEmail(String? email) {
    final normalized = _normalize(email)?.toLowerCase();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _normalize(prefs.getString(_deviceIdKey));
    if (existing != null) return existing;

    final id = _uuid.v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<DateTime?> readPlatformAccessRequestedAtUtc({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = _normalize(
      prefs.getString('$_platformAccessRequestedAtUtcPrefix$normalizedEmail'),
    );
    if (raw == null) return null;

    return DateTime.tryParse(raw);
  }

  Future<void> writePlatformAccessRequestedAtUtc({
    required String email,
    required DateTime? requestedAtUtc,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_platformAccessRequestedAtUtcPrefix$normalizedEmail';
    if (requestedAtUtc == null) {
      await prefs.remove(key);
      return;
    }

    await prefs.setString(key, requestedAtUtc.toUtc().toIso8601String());
  }

  Future<void> _migratePrefsToSecureIfNeeded() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final jwt = _normalize(prefs.getString(_tokenKey));
    final email = _normalize(prefs.getString(_emailKey));
    final tenantId = _normalize(prefs.getString(_tenantIdKey));
    final tenantName = _normalize(prefs.getString(_tenantNameKey));

    if (jwt == null &&
        email == null &&
        tenantId == null &&
        tenantName == null) {
      return;
    }

    final existingJwt = _normalize(await _secureStorage.read(key: _tokenKey));
    final existingEmail = _normalize(await _secureStorage.read(key: _emailKey));
    final existingTenantId = _normalize(
      await _secureStorage.read(key: _tenantIdKey),
    );
    final existingTenantName = _normalize(
      await _secureStorage.read(key: _tenantNameKey),
    );

    if (existingJwt == null && jwt != null) {
      await _secureStorage.write(key: _tokenKey, value: jwt);
    }
    if (existingEmail == null && email != null) {
      await _secureStorage.write(key: _emailKey, value: email);
    }
    if (existingTenantId == null && tenantId != null) {
      await _secureStorage.write(key: _tenantIdKey, value: tenantId);
    }
    if (existingTenantName == null && tenantName != null) {
      await _secureStorage.write(key: _tenantNameKey, value: tenantName);
    }

    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_tenantNameKey);
  }

  Future<String?> readToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getString(_tokenKey));
    }

    await _migratePrefsToSecureIfNeeded();
    return _normalize(await _secureStorage.read(key: _tokenKey));
  }

  Future<String?> readPlatformToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getString(_platformTokenKey));
    }

    return _normalize(await _secureStorage.read(key: _platformTokenKey));
  }

  Future<void> writePlatformToken(String? token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = _normalize(token);
      if (value == null) {
        await prefs.remove(_platformTokenKey);
      } else {
        await prefs.setString(_platformTokenKey, value);
      }
      return;
    }

    final value = _normalize(token);
    if (value == null) {
      await _secureStorage.delete(key: _platformTokenKey);
    } else {
      await _secureStorage.write(key: _platformTokenKey, value: value);
    }
  }

  Future<bool> readPlatformBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_platformBiometricsEnabledKey) ?? false;
  }

  Future<void> writePlatformBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_platformBiometricsEnabledKey, enabled);
  }

  Future<void> writeToken(String? token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = _normalize(token);
      if (value == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, value);
      }
      return;
    }

    final value = _normalize(token);
    if (value == null) {
      await _secureStorage.delete(key: _tokenKey);
    } else {
      await _secureStorage.write(key: _tokenKey, value: value);
    }
  }

  Future<String?> readEmail() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getString(_emailKey));
    }

    await _migratePrefsToSecureIfNeeded();
    return _normalize(await _secureStorage.read(key: _emailKey));
  }

  Future<void> writeEmail(String? email) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = _normalize(email);
      if (value == null) {
        await prefs.remove(_emailKey);
      } else {
        await prefs.setString(_emailKey, value);
      }
      return;
    }

    final value = _normalize(email);
    if (value == null) {
      await _secureStorage.delete(key: _emailKey);
    } else {
      await _secureStorage.write(key: _emailKey, value: value);
    }
  }

  Future<String?> readTenantId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getString(_tenantIdKey));
    }

    await _migratePrefsToSecureIfNeeded();
    return _normalize(await _secureStorage.read(key: _tenantIdKey));
  }

  Future<String?> readTenantName() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getString(_tenantNameKey));
    }

    await _migratePrefsToSecureIfNeeded();
    return _normalize(await _secureStorage.read(key: _tenantNameKey));
  }

  Future<void> writeTenantId(String? tenantId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = _normalize(tenantId);
      if (value == null) {
        await prefs.remove(_tenantIdKey);
      } else {
        await prefs.setString(_tenantIdKey, value);
      }
      return;
    }

    final value = _normalize(tenantId);
    if (value == null) {
      await _secureStorage.delete(key: _tenantIdKey);
    } else {
      await _secureStorage.write(key: _tenantIdKey, value: value);
    }
  }

  Future<void> writeTenantName(String? tenantName) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = _normalize(tenantName);
      if (value == null) {
        await prefs.remove(_tenantNameKey);
      } else {
        await prefs.setString(_tenantNameKey, value);
      }
      return;
    }

    final value = _normalize(tenantName);
    if (value == null) {
      await _secureStorage.delete(key: _tenantNameKey);
    } else {
      await _secureStorage.write(key: _tenantNameKey, value: value);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_platformTokenKey);
    await prefs.remove(_platformBiometricsEnabledKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_tenantNameKey);
    await prefs.remove(_tenantOptionsEmailKey);
    await prefs.remove(_tenantOptionsJsonKey);

    if (!kIsWeb) {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _platformTokenKey);
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _tenantIdKey);
      await _secureStorage.delete(key: _tenantNameKey);
    }
  }

  Future<void> writeTenantOptionsCache({
    required String email,
    required String json,
  }) async {
    final normalizedEmail = _normalize(email) ?? '';
    final normalizedJson = _normalize(json) ?? '';

    final prefs = await SharedPreferences.getInstance();
    if (normalizedEmail.isEmpty || normalizedJson.isEmpty) {
      await prefs.remove(_tenantOptionsEmailKey);
      await prefs.remove(_tenantOptionsJsonKey);
      return;
    }

    await prefs.setString(_tenantOptionsEmailKey, normalizedEmail);
    await prefs.setString(_tenantOptionsJsonKey, normalizedJson);
  }

  Future<String?> readTenantOptionsCacheJson({required String email}) async {
    final normalizedEmail = _normalize(email);
    if (normalizedEmail == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = _normalize(prefs.getString(_tenantOptionsEmailKey));
    if (cachedEmail == null ||
        cachedEmail.toLowerCase() != normalizedEmail.toLowerCase()) {
      return null;
    }

    return _normalize(prefs.getString(_tenantOptionsJsonKey));
  }
}
