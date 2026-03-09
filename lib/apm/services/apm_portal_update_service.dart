import '../../app/app_config.dart';
import '../../auth/auth_session.dart';
import '../../logging/apm_logger.dart';
import '../database/database_helper.dart';
import '../models/update_check_result.dart';
import 'portal_api_client.dart';
import 'update_service.dart';

class ApmPortalUpdateService implements UpdateService {
  ApmPortalUpdateService({
    required this.session,
    PortalApiClient? client,
    DatabaseHelper? db,
  }) : client = client ?? PortalApiClient(baseUrl: AppConfig.apiBaseUrl),
       db = db ?? DatabaseHelper.instance;

  static const String _installedServerBuildIdKey =
      'apm_update.server_build.installed_build_id';

  static const String _installedServerBuildIdAppVersionKey =
      'apm_update.server_build.installed_build_id.app_version';

  static const String _lastSeenServerBuildIdKey =
      'apm_update.server_build.last_seen_build_id';

  final AuthSession session;
  final PortalApiClient client;
  final DatabaseHelper db;

  @override
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  }) async {
    final token = (session.state.value?.token ?? '').trim();
    if (token.isEmpty) {
      return UpdateCheckResult.noUpdate(
        currentVersionName: currentVersionName,
        currentVersionCode: currentVersionCode,
      );
    }

    var installedAt = await db.getInstallDate();
    installedAt ??= DateTime.now().toUtc();
    await db.setInstallDate(installedAt);

    final appVersion = '$currentVersionName+$currentVersionCode';

    // If the appVersion changes (fresh install / manual APK update), clear any persisted
    // server build baseline so we don't get stuck in a forced-update loop.
    final installedBuildIdAppVersionRaw = await db.getSetting(
      _installedServerBuildIdAppVersionKey,
    );
    final installedBuildIdAppVersion = installedBuildIdAppVersionRaw?.trim();
    if (installedBuildIdAppVersion != null &&
        installedBuildIdAppVersion.isNotEmpty &&
        installedBuildIdAppVersion != appVersion) {
      await db.deleteSetting(_installedServerBuildIdKey);
    }

    final installedBuildIdRaw = await db.getSetting(_installedServerBuildIdKey);
    final installedBuildId = installedBuildIdRaw?.trim();

    final query = {
      'installedAt': installedAt.toIso8601String(),
      'appVersion': appVersion,
      'versionName': currentVersionName,
      'versionCode': currentVersionCode.toString(),
      if (installedBuildId != null && installedBuildId.isNotEmpty)
        'installedBuildId': installedBuildId,
    };

    final queryString = Uri(queryParameters: query).query;

    final json = await client.getJson(
      '/api/apm/app/builds/update-check?$queryString',
      bearerToken: token,
    );

    if (!PortalApiClient.readResultSuccess(json)) {
      return UpdateCheckResult.noUpdate(
        currentVersionName: currentVersionName,
        currentVersionCode: currentVersionCode,
      );
    }

    final data = json['Data'] ?? json['data'];
    if (data is! Map) {
      return UpdateCheckResult.noUpdate(
        currentVersionName: currentVersionName,
        currentVersionCode: currentVersionCode,
      );
    }

    final serverUpdateAvailable =
        data['updateAvailable'] == true || data['UpdateAvailable'] == true;

    final currentBuildIdRaw =
        data['currentBuildId']?.toString() ??
        data['CurrentBuildId']?.toString();
    final currentBuildId = currentBuildIdRaw?.trim();

    if (currentBuildId != null && currentBuildId.isNotEmpty) {
      await db.saveSetting(_lastSeenServerBuildIdKey, currentBuildId);
    }

    final version = data['version']?.toString() ?? data['Version']?.toString();
    final downloadUrl =
        data['downloadUrl']?.toString() ?? data['DownloadUrl']?.toString();
    final releaseNotes =
        data['releaseNotes']?.toString() ?? data['ReleaseNotes']?.toString();

    final latestVersionName = (version?.trim().isNotEmpty ?? false)
        ? version!.trim()
        : currentVersionName;

    final latestVersionCode =
        _tryParseVersionCode(latestVersionName) ?? currentVersionCode;

    // Extra guard: if the server claims an update is available but the SemVer is identical,
    // treat it as no-update. This protects against legacy server behavior where an APK
    // filename contains a non-versionCode "+<number>" segment.
    if (serverUpdateAvailable) {
      final installedSemVer = _tryExtractSemVer(currentVersionName);
      final latestSemVer = _tryExtractSemVer(latestVersionName);
      if (installedSemVer != null &&
          latestSemVer != null &&
          installedSemVer == latestSemVer) {
        ApmLogger.warning(
          'Update-check: serverUpdateAvailable=true but semver equal (installed={Installed} latest={Latest})',
          args: [installedSemVer, latestSemVer],
          category: 'Updates',
        );

        if (currentBuildId != null && currentBuildId.isNotEmpty) {
          await db.saveSetting(_installedServerBuildIdKey, currentBuildId);
          await db.saveSetting(
            _installedServerBuildIdAppVersionKey,
            appVersion,
          );
        }

        return UpdateCheckResult(
          isUpdateAvailable: false,
          isUpdateRequired: false,
          latestVersionName: latestVersionName,
          latestVersionCode: latestVersionCode,
          isTestUpdateAvailable: false,
        );
      }
    }

    // Primary: compare persisted server build fingerprint (when present).
    // Fallback: server updateAvailable for legacy clients/servers.
    bool updateRequired;
    if (currentBuildId != null && currentBuildId.isNotEmpty) {
      if (installedBuildId != null && installedBuildId.isNotEmpty) {
        updateRequired = installedBuildId != currentBuildId;
      } else {
        updateRequired = serverUpdateAvailable;
      }
    } else {
      updateRequired = serverUpdateAvailable;
    }

    if (!updateRequired) {
      if (currentBuildId != null && currentBuildId.isNotEmpty) {
        await db.saveSetting(_installedServerBuildIdKey, currentBuildId);
        await db.saveSetting(_installedServerBuildIdAppVersionKey, appVersion);
      }

      return UpdateCheckResult(
        isUpdateAvailable: false,
        isUpdateRequired: false,
        latestVersionName: latestVersionName,
        latestVersionCode: latestVersionCode,
        isTestUpdateAvailable: false,
      );
    }

    ApmLogger.info(
      'Update available: {LatestVersion} (serverBuildId={ServerBuildId})',
      args: [latestVersionName, currentBuildId ?? ''],
      category: 'Updates',
    );

    return UpdateCheckResult(
      isUpdateAvailable: true,
      isUpdateRequired: true,
      latestVersionName: latestVersionName,
      latestVersionCode: latestVersionCode,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      isTestUpdateAvailable: false,
    );
  }

  @override
  Future<void> reportInstallSuccess({
    required String versionName,
    required int versionCode,
  }) async {
    final token = (session.state.value?.token ?? '').trim();
    if (token.isEmpty) return;

    try {
      await client.postJson(
        '/api/apm/app/activate',
        bearerToken: token,
        body: {'appVersion': '$versionName+$versionCode'},
      );

      await db.setInstallDate(DateTime.now().toUtc());

      ApmLogger.info(
        'Install reported: {Version}',
        args: ['$versionName+$versionCode'],
        category: 'Updates',
      );
    } catch (_) {
      // Best-effort.
    }
  }

  int? _tryParseVersionCode(String? versionName) {
    if (versionName == null) return null;
    final plusIndex = versionName.lastIndexOf('+');
    if (plusIndex < 0 || plusIndex == versionName.length - 1) return null;
    final codeValue = versionName.substring(plusIndex + 1).trim();
    return int.tryParse(codeValue);
  }

  String? _tryExtractSemVer(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d+(?:\.\d+){1,3})').firstMatch(value.trim());
    return match?.group(1);
  }
}
