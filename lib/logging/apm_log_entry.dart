class ApmLogEntry {
  ApmLogEntry({
    required this.id,
    required this.createdUtcIso,
    required this.level,
    required this.message,
    this.category,
    this.error,
    this.stackTrace,
  });

  final String id;
  final String createdUtcIso;
  final ApmLogLevel level;
  final String message;
  final String? category;
  final String? error;
  final String? stackTrace;
}

enum ApmLogLevel { warning, error, fatal }
