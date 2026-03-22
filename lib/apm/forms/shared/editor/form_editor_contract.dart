enum FormEditorRuntimeMode { mobileDraft, webEditor }

class FormEditorCompletion {
  const FormEditorCompletion({
    required this.formType,
    required this.formData,
    this.localFormId,
    this.formUuid,
  });

  final String formType;
  final Map<String, dynamic> formData;
  final int? localFormId;
  final String? formUuid;
}

typedef FormEditorCompleteHandler =
    Future<void> Function(FormEditorCompletion completion);
