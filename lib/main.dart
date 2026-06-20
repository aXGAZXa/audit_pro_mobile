import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';

import 'app/audit_pro_app.dart';
import 'app/app_config.dart';
import 'apm/database/gt_database_bootstrap.dart';
import 'logging/apm_logger.dart';
import 'logging/apm_device_log_upload_service.dart';

/// Singleton uploader: drains persisted device logs to the server. Started after
/// auth/runtime init below. Exposed so other entry points could trigger a flush.
final ApmDeviceLogUploadService apmDeviceLogUploader =
    ApmDeviceLogUploadService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApmLogger.init();

  // GTErrorHandler installs the global handlers (console dump + debug UI). We
  // then CHAIN our own capture in front of the handlers it set so uncaught
  // Flutter-framework and async/platform errors are also persisted via
  // ApmLogger (→ uploaded to the portal) without losing GTErrorHandler's
  // existing behavior.
  GTErrorHandler.initialize();
  _installApmErrorCapture();

  // Bootstrap gtapp_dart's GTDatabaseService for the generic forms runtime so it
  // can persist image-question file metadata (GTImage). This is additive and
  // independent of the live CR/HNA persistence (database_helper.dart).
  //
  // NOT on web: the web build is the form web editor, which has no local DB —
  // images live in R2 and are resolved through GTFileManagerConfig's remote
  // resolver. Opening sqflite on web would require the (unbundled)
  // `sqflite_sw.js` worker and 404, so the web editor never touches it.
  if (!kIsWeb) {
    await GtDatabaseBootstrap.init();
  }

  // Forms-unification generic runtime: register declarative form components
  // (polymorphic deserialization) + question widgets ONCE at startup so the
  // generic GTDeclarativeFormView can render data-defined forms. Additive and
  // non-disruptive — the live hard-coded CR/HNA screens do not use these.
  registerFormComponents();
  registerQuestionWidgets();

  ApmLogger.info(
    'AuditPro Mobile starting '
    '(web: {Web}, release: {Release}, '
    'apiBaseUrlOverrideSet: {ApiOverrideSet}, '
    'definesSource: {DefinesSource}, '
    'mobileAuthKeySet: {KeySet}, mobileAuthKeyLen: {KeyLen})',
    args: [
      kIsWeb,
      kReleaseMode,
      AppConfig.apiBaseUrlOverride.isNotEmpty,
      AppConfig.definesSource,
      AppConfig.mobileAuthApiKey.isNotEmpty,
      AppConfig.mobileAuthApiKey.length,
    ],
    category: 'Startup',
  );

  // Start the device-log uploader: registers the post-error flush trigger and
  // performs a start-up flush of any backlog. Fire-and-forget + best-effort;
  // it only attempts when a mobile JWT is present and never throws.
  if (!kIsWeb) {
    apmDeviceLogUploader.start();
  }

  runApp(const AuditProApp());
}

/// Chains ApmLogger capture onto the global error handlers that
/// [GTErrorHandler.initialize] already installed. We capture the existing
/// handlers and call through to them, so GTErrorHandler's console dump + debug
/// UI keep working while every uncaught error also becomes an ApmLogger entry
/// (persisted locally → uploaded to the portal).
void _installApmErrorCapture() {
  // Flutter framework errors (build/layout/paint, etc.).
  final priorFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      ApmLogger.error(
        'Uncaught Flutter error: {Summary}',
        args: [details.exceptionAsString()],
        category: 'UncaughtError/Flutter',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      );
    } catch (_) {
      // Capture must never interfere with the framework's error path.
    }
    priorFlutterOnError?.call(details);
  };

  // Uncaught async / platform errors (Future failures, platform channels).
  final priorPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      ApmLogger.fatal(
        'Uncaught async error: {Error}',
        args: [error.toString()],
        category: 'UncaughtError/Async',
        error: error,
        stackTrace: stack,
      );
    } catch (_) {
      // Never let capture swallow/alter the handler's return contract.
    }
    // Preserve GTErrorHandler's handler (which returns true to keep the app
    // alive). Default to true if none was set.
    return priorPlatformOnError?.call(error, stack) ?? true;
  };
}
