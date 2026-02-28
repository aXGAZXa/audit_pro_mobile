import 'apm_log_entry.dart';
import 'apm_log_sink.dart';

class ApmLogSinkImpl implements ApmLogSink {
  @override
  Future<void> init() async {}

  @override
  Future<void> write(ApmLogEntry entry) async {}
}
