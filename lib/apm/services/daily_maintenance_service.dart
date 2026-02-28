import 'package:flutter/material.dart';

import '../../auth/auth_session.dart';
import '../../auth/mobile_auth_api.dart';
import '../../logging/apm_logger.dart';
import '../database/database_helper.dart';
import '../forms/heat_network_assessment/services/hna_retention_cleanup_service.dart';

class DailyMaintenanceService {
  DailyMaintenanceService({
    DatabaseHelper? db,
    AuthSession? session,
    MobileAuthApi? authApi,
  }) : _db = db ?? DatabaseHelper.instance,
       _session = session,
       _authApi = authApi ?? MobileAuthApi();

  static const String lastRunAtKey = 'daily_maintenance.last_run_at';

  final DatabaseHelper _db;
  final AuthSession? _session;
  final MobileAuthApi _authApi;

  Future<void> _refreshAuthTokenBestEffort() async {
    final session = _session;
    if (session == null) return;

    final current = session.state.value;
    if (current == null) return;

    final token = current.token.trim();
    if (token.isEmpty) return;

    final res = await _authApi.refresh(token: token);
    final refreshed = (res.data ?? '').trim();

    if (res.success && refreshed.isNotEmpty) {
      await session.updateToken(refreshed);
      ApmLogger.info('Daily token refresh ok', category: 'DailyMaintenance');
      return;
    }

    // If the server clearly indicates the session is no longer valid, clear it
    // so the user can sign in again.
    if (res.statusCode == 401 || res.statusCode == 403) {
      ApmLogger.warning(
        'Daily token refresh unauthorized; signing out',
        category: 'DailyMaintenance',
      );
      await session.signOut();
      return;
    }

    ApmLogger.warning(
      'Daily token refresh failed (status={StatusCode}, message={Message})',
      args: [res.statusCode, res.message],
      category: 'DailyMaintenance',
    );
  }

  Future<DateTime?> getLastRunAt() async {
    final raw = await _db.getSetting(lastRunAtKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  Future<void> setLastRunAt(DateTime value) async {
    await _db.saveSetting(lastRunAtKey, value.toIso8601String());
  }

  Future<bool> isDue({DateTime? now}) async {
    final last = await getLastRunAt();
    final current = now ?? DateTime.now();

    if (last == null) return true;

    final lastLocalDay = DateUtils.dateOnly(last.toLocal());
    final todayLocalDay = DateUtils.dateOnly(current.toLocal());

    return lastLocalDay.isBefore(todayLocalDay);
  }

  Future<void> runIfDue({
    DateTime? now,
    List<Future<void> Function()> tasks = const [],
    List<Future<void> Function()> additionalTasks = const [],
  }) async {
    final current = now ?? DateTime.now();

    final due = await isDue(now: current);
    if (!due) return;

    final baseTasks = tasks.isEmpty
        ? <Future<void> Function()>[
            _refreshAuthTokenBestEffort,
            () => HnaRetentionCleanupService(db: _db).runBestEffort(),
          ]
        : tasks;

    final effectiveTasks = <Future<void> Function()>[
      ...baseTasks,
      ...additionalTasks,
    ];

    ApmLogger.info(
      'Daily maintenance start tasks=${effectiveTasks.length}',
      category: 'DailyMaintenance',
    );

    for (final t in effectiveTasks) {
      try {
        await t();
      } catch (e, st) {
        ApmLogger.warning(
          'Daily maintenance task failed: {Error}',
          args: [e.toString()],
          category: 'DailyMaintenance',
          error: e,
          stackTrace: st,
        );
      }
    }

    ApmLogger.info('Daily maintenance complete', category: 'DailyMaintenance');

    await setLastRunAt(current);
  }
}
