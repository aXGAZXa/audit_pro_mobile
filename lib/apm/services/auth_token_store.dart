import 'package:audit_pro_mobile/auth/auth_storage.dart';

class AuthTokenStore {
  AuthTokenStore({AuthStorage? storage}) : _storage = storage ?? AuthStorage();

  final AuthStorage _storage;

  Future<void> setAccessToken({
    required String token,
    required DateTime expiresAt,
  }) async {
    // APM owns authentication and token persistence. Downstream features read
    // the token from APM storage; they should not attempt to write or manage
    // tokens themselves.
    //
    // Intentionally a no-op.
  }

  Future<String?> getAccessToken() async {
    // HNA must use the tenant-scoped APM token (mobile_app). Platform access
    // tokens are for separate portal features and must not be required here.
    return _storage.readToken();
  }

  Future<DateTime?> getAccessTokenExpiry() async {
    // APM does not currently track token expiry client-side.
    return null;
  }

  Future<void> clear() async {
    // HNA should not clear the app's auth session.
  }
}
