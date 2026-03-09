import '../models/app_version.dart';
import '../models/update_check_result.dart';
import 'app_info_service.dart';
import 'update_service.dart';
import 'update_state_store.dart';

class UpdateFlowResult {
  UpdateFlowResult({required this.currentVersion, required this.checkResult});

  final AppVersion currentVersion;
  final UpdateCheckResult checkResult;
}

class UpdateCoordinator {
  UpdateCoordinator({
    required this.updateService,
    required this.stateStore,
    required this.appInfoService,
  });

  final UpdateService updateService;
  final UpdateStateStore stateStore;
  final AppInfoService appInfoService;

  Future<UpdateFlowResult> checkForUpdates() async {
    final currentVersion = await appInfoService.getCurrentVersion();
    final checkResult = await updateService.checkForUpdate(
      currentVersionName: currentVersion.name,
      currentVersionCode: currentVersion.code,
    );

    if (!checkResult.isUpdateRequired) {
      await _reportInstallIfNeeded(currentVersion);
    }

    return UpdateFlowResult(
      currentVersion: currentVersion,
      checkResult: checkResult,
    );
  }

  Future<void> _reportInstallIfNeeded(AppVersion currentVersion) async {
    final lastReported = await stateStore.getLastReportedVersionCode();
    if (lastReported == currentVersion.code) {
      return;
    }

    await updateService.reportInstallSuccess(
      versionName: currentVersion.name,
      versionCode: currentVersion.code,
    );

    await stateStore.setLastReportedVersionCode(currentVersion.code);
  }
}
