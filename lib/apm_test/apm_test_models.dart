class ApmTestFormSubmission {
  ApmTestFormSubmission({
    required this.id,
    required this.formKey,
    required this.clientSubmissionId,
    required this.payloadJson,
    required this.revision,
    required this.submittedByEmail,
    required this.submittedAtUtc,
  });

  final String id;
  final String formKey;
  final String? clientSubmissionId;
  final String payloadJson;
  final int revision;
  final String submittedByEmail;
  final DateTime submittedAtUtc;

  factory ApmTestFormSubmission.fromJson(Map<String, dynamic> json) {
    return ApmTestFormSubmission(
      id: (json['id'] ?? '').toString(),
      formKey: (json['formKey'] ?? '').toString(),
      clientSubmissionId: (json['clientSubmissionId'] as String?)?.trim(),
      payloadJson: (json['payloadJson'] ?? '{}').toString(),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      submittedByEmail: (json['submittedByEmail'] ?? '').toString(),
      submittedAtUtc:
          DateTime.tryParse((json['submittedAtUtc'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
