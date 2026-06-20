import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';

import 'apm_log_entry.dart';
import 'apm_log_sink.dart';
import 'apm_log_sink_stub.dart' if (dart.library.io) 'apm_log_sink_mobile.dart';

class ApmLogger {
  static final ApmLogSink _sink = ApmLogSinkImpl();
  static bool _initialized = false;

  /// Optional flush trigger registered by the device-log upload service. Invoked
  /// (best-effort, fire-and-forget by the registrant) after an error/fatal entry
  /// is persisted so newly captured problems are pushed to the server promptly.
  ///
  /// Kept as a plain callback so the logger has no dependency on the upload
  /// service (which depends on the logger). Failures in the callback must never
  /// propagate back here and must never themselves call ApmLogger.error/fatal
  /// (that would recurse). The registrant is responsible for debouncing.
  static void Function()? onFlushRequested;

  /// Exposes persisted-but-unuploaded rows for the upload service. Returns an
  /// empty list before init / on web. Never throws into callers.
  static Future<List<ApmLogEntry>> readUnuploaded({int limit = 50}) async {
    if (!_initialized || kIsWeb) return <ApmLogEntry>[];
    try {
      return await _sink.readUnuploaded(limit: limit);
    } catch (_) {
      return <ApmLogEntry>[];
    }
  }

  /// Marks rows as uploaded after a successful server POST. Never throws.
  static Future<void> markUploaded(List<String> ids) async {
    if (!_initialized || kIsWeb || ids.isEmpty) return;
    try {
      await _sink.markUploaded(ids);
    } catch (_) {
      // Swallow: worst case the rows are re-sent next flush (idempotent upsert
      // on the server side keyed by client log id).
    }
  }

  static String? _cat(String? category) {
    final trimmed = (category ?? '').trim();
    if (trimmed.isEmpty) return 'APM';
    if (trimmed.startsWith('APM/')) return trimmed;
    return 'APM/$trimmed';
  }

  static String _ts() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }

  static String _withTs(String message) => '[${_ts()}] $message';

  static Future<void> init() async {
    if (_initialized) return;

    final isProduction = kReleaseMode;
    GTLogger.configure(
      consoleMinLevel: isProduction ? Level.warning : Level.debug,
      isProduction: isProduction,
    );

    if (!kIsWeb) {
      try {
        await _sink.init();
      } catch (e, st) {
        GTLogger.warning('Log DB init failed: {Error}', [
          e.toString(),
        ], 'ApmLogger');
        GTLogger.debug('Log DB init stack: {Stack}', [
          st.toString(),
        ], 'ApmLogger');
      }
    }

    _initialized = true;
  }

  static void debug(String message, {List<Object?>? args, String? category}) {
    if (kReleaseMode) return;
    GTLogger.debug(_withTs(message), args, _cat(category));
  }

  static void info(String message, {List<Object?>? args, String? category}) {
    if (kReleaseMode) return;
    GTLogger.info(_withTs(message), args, _cat(category));
  }

  static void warning(
    String message, {
    List<Object?>? args,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final msg = _withTs(message);
    GTLogger.warning(msg, args, _cat(category));
    _persist(
      level: ApmLogLevel.warning,
      message: _formatMessage(msg, args),
      category: _cat(category),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    List<Object?>? args,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final msg = _withTs(message);
    GTLogger.error(msg, args, _cat(category), error, stackTrace);
    _persist(
      level: ApmLogLevel.error,
      message: _formatMessage(msg, args),
      category: _cat(category),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void fatal(
    String message, {
    List<Object?>? args,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final msg = _withTs(message);
    GTLogger.fatal(msg, args, _cat(category), error, stackTrace);
    _persist(
      level: ApmLogLevel.fatal,
      message: _formatMessage(msg, args),
      category: _cat(category),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _persist({
    required ApmLogLevel level,
    required String message,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_initialized || kIsWeb) return;

    final entry = ApmLogEntry(
      id: _newId(),
      createdUtcIso: DateTime.now().toUtc().toIso8601String(),
      level: level,
      category: category,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    unawaited(
      _sink.write(entry).catchError((e, st) {
        GTLogger.warning('Log DB write failed: {Error}', [
          e.toString(),
        ], 'ApmLogger');
        GTLogger.debug('Log DB write stack: {Stack}', [
          st.toString(),
        ], 'ApmLogger');
      }),
    );

    // Nudge the upload service to flush soon (it debounces). Only for the more
    // severe levels to avoid excessive uploads from warning bursts; warnings
    // still ride along on the next start/error/periodic flush. Guarded so a
    // throwing callback never disrupts logging or recurses into ApmLogger.
    if (level == ApmLogLevel.error || level == ApmLogLevel.fatal) {
      final cb = onFlushRequested;
      if (cb != null) {
        try {
          cb();
        } catch (_) {
          // Never let a flush-trigger failure affect logging.
        }
      }
    }
  }

  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(1 << 32);
    return '${now}_$r';
  }

  static String _formatMessage(String template, List<Object?>? args) {
    if (args == null || args.isEmpty) return template;

    var result = template;
    var argIndex = 0;
    result = result.replaceAllMapped(RegExp(r'\{[^}]+\}'), (match) {
      if (argIndex < args.length) {
        final value = args[argIndex++];
        return value?.toString() ?? 'null';
      }
      return match.group(0)!;
    });
    return result;
  }
}
