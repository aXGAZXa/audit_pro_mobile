import 'apm_log_entry.dart';
import 'apm_log_sink.dart';

class ApmLogSinkImpl implements ApmLogSink {
  @override
  Future<void> init() async {}

  @override
  Future<void> write(ApmLogEntry entry) async {}

  @override
  Future<List<ApmLogEntry>> readUnuploaded({int limit = 50}) async =>
      <ApmLogEntry>[];

  @override
  Future<void> markUploaded(List<String> ids) async {}
}
