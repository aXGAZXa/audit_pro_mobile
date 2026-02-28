class UpdateCheckResult {
  const UpdateCheckResult({
    required this.isUpdateAvailable,
    required this.isUpdateRequired,
    required this.latestVersionName,
    required this.latestVersionCode,
    this.downloadUrl,
    this.releaseNotes,
    this.isTestUpdateAvailable = false,
    this.testVersionName,
    this.testVersionCode,
    this.testDownloadUrl,
    this.testReleaseNotes,
  });

  final bool isUpdateAvailable;
  final bool isUpdateRequired;
  final String latestVersionName;
  final int latestVersionCode;
  final String? downloadUrl;
  final String? releaseNotes;

  final bool isTestUpdateAvailable;
  final String? testVersionName;
  final int? testVersionCode;
  final String? testDownloadUrl;
  final String? testReleaseNotes;

  static UpdateCheckResult noUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  }) {
    return UpdateCheckResult(
      isUpdateAvailable: false,
      isUpdateRequired: false,
      latestVersionName: currentVersionName,
      latestVersionCode: currentVersionCode,
      isTestUpdateAvailable: false,
    );
  }
}
