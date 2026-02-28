import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';

import 'apm_logger.dart';

class ApmFeedback {
  static void success(
    BuildContext context,
    String message, {
    String? logMessage,
    List<Object?>? logArgs,
    String? category,
  }) {
    GTNotificationService.showSuccess(context, message);
    ApmLogger.info(logMessage ?? message, args: logArgs, category: category);
  }

  static void info(
    BuildContext context,
    String message, {
    String? logMessage,
    List<Object?>? logArgs,
    String? category,
  }) {
    GTNotificationService.showInfo(context, message);
    ApmLogger.info(logMessage ?? message, args: logArgs, category: category);
  }

  static void warning(
    BuildContext context,
    String message, {
    String? logMessage,
    List<Object?>? logArgs,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    GTNotificationService.showWarning(context, message);
    ApmLogger.warning(
      logMessage ?? message,
      args: logArgs,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? logMessage,
    List<Object?>? logArgs,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    GTNotificationService.showError(context, message);
    ApmLogger.error(
      logMessage ?? message,
      args: logArgs,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
