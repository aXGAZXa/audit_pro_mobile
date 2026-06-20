import 'apm_log_entry.dart';

abstract class ApmLogSink {
  Future<void> init();
  Future<void> write(ApmLogEntry entry);

  /// Reads up to [limit] persisted log rows that have not yet been uploaded to
  /// the server, oldest first. Returns an empty list when none are pending or
  /// when the sink has no backing store (e.g. the web stub).
  Future<List<ApmLogEntry>> readUnuploaded({int limit = 50});

  /// Marks the rows with the given [ids] as uploaded so they are not sent again.
  Future<void> markUploaded(List<String> ids);
}
