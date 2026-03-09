import '../database/database_helper.dart';

class UpdateStateStore {
  UpdateStateStore({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  static const String _lastReportedVersionCodeKey =
      'apm_update.last_reported_version_code';

  final DatabaseHelper _db;

  Future<int?> getLastReportedVersionCode() async {
    final raw = await _db.getSetting(_lastReportedVersionCodeKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> setLastReportedVersionCode(int versionCode) async {
    await _db.saveSetting(_lastReportedVersionCodeKey, versionCode.toString());
  }
}
