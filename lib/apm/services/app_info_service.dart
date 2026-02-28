import 'package:package_info_plus/package_info_plus.dart';

import 'package:audit_pro_mobile/apm/models/app_version.dart';

class AppInfoService {
  Future<AppVersion> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    final buildCode = int.tryParse(info.buildNumber) ?? 0;
    return AppVersion(name: info.version, code: buildCode);
  }
}
