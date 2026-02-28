import 'apm_log_entry.dart';

abstract class ApmLogSink {
  Future<void> init();
  Future<void> write(ApmLogEntry entry);
}
