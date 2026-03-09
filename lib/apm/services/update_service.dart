import '../models/update_check_result.dart';

abstract class UpdateService {
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  });

  Future<void> reportInstallSuccess({
    required String versionName,
    required int versionCode,
  });
}
