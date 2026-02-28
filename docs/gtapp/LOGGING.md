# GTApp Logging – APM Guide

APM uses `GTLogger` from `gtapp_dart`.

## Configure once at startup

Call this in `main()` before any real work:

```dart
import 'package:gtapp_mobile/gtapp_mobile.dart';

void configureLogging() {
  final isProd = const bool.fromEnvironment('dart.vm.product');

  GTLogger.configure(
    consoleMinLevel: isProd ? Level.warning : Level.debug,
    isProduction: isProd,
  );
}
```

Notes:
- Logging does **early filtering**: if a level is suppressed, message formatting work is skipped.
- `fatal(...)` always logs.

## How to log (message templates)

Prefer structured templates with args:

```dart
GTLogger.info(
  'User {Email} logged in (tenant={TenantId})',
  [email, tenantId],
  'AuthService',
);
```

Don’t interpolate strings (harder to search/parse):

```dart
// avoid
GTLogger.info('User $email logged in', [], 'AuthService');
```

## Categories (the 3rd parameter)

In this codebase, category is a simple string. Be consistent:
- use the service/class name: `AuthService`, `FormSyncService`, `GTDatabaseService`
- avoid per-call dynamic categories

## Errors and stack traces

```dart
try {
  await db.saveAsync(entity);
} catch (e, st) {
  GTLogger.error(
    'Failed to save {Type} {Id}',
    [entity.runtimeType, entity.id],
    'MyService',
    e,
    st,
  );
}
```

## Use `show()` for “always print” startup messages

`GTLogger.show(...)` bypasses filters and formatting (good for startup banners and migration completion).
