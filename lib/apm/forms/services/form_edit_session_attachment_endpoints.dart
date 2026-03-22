class FormEditSessionAttachmentEndpoints {
  const FormEditSessionAttachmentEndpoints({
    required this.contentPath,
    required this.localFolderName,
  });

  final String Function(String submissionId, String attachmentId) contentPath;
  final String localFolderName;

  factory FormEditSessionAttachmentEndpoints.forFormResponses() {
    return FormEditSessionAttachmentEndpoints(
      contentPath: (submissionId, attachmentId) =>
          '/api/forms/responses/$submissionId/attachments/$attachmentId/content',
      localFolderName: 'form_attachments',
    );
  }

  factory FormEditSessionAttachmentEndpoints.forHnaAssessments() {
    return FormEditSessionAttachmentEndpoints(
      contentPath: (submissionId, attachmentId) =>
          '/api/hna/assessments/$submissionId/attachments/$attachmentId/content',
      localFolderName: 'form_attachments',
    );
  }
}
