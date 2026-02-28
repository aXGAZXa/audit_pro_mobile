import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';

import 'app/audit_pro_app.dart';
import 'app/app_config.dart';
import 'logging/apm_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApmLogger.init();
  GTErrorHandler.initialize();

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

  runApp(const AuditProApp());
}
