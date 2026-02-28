import 'package:image_picker/image_picker.dart';

/// Represents a form in the database
class FormModel {
  final int? id;
  final String formType;
  final String status; // draft, pending, sent
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> formData;

  FormModel({
    this.id,
    required this.formType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.formData,
  });

  factory FormModel.fromMap(Map<String, dynamic> map) {
    return FormModel(
      id: map['id'],
      formType: map['form_type'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      formData: map['form_data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'form_type': formType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'form_data': formData,
    };
  }

  FormModel copyWith({
    int? id,
    String? formType,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? formData,
  }) {
    return FormModel(
      id: id ?? this.id,
      formType: formType ?? this.formType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      formData: formData ?? this.formData,
    );
  }
}

/// Represents an observation linked to a question
class ObservationModel {
  final int? id;
  final int formId;
  final String questionReference;
  final String? notes;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  ObservationModel({
    this.id,
    required this.formId,
    required this.questionReference,
    this.notes,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ObservationModel.fromMap(Map<String, dynamic> map) {
    return ObservationModel(
      id: map['id'],
      formId: map['form_id'],
      questionReference: map['question_reference'],
      notes: map['notes'],
      imagePaths:
          (map['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  /// Convert from the format used by AddObservationScreen
  /// `{notes: String, images: List<XFile>}`
  static ObservationModel fromAddObservationData({
    required int formId,
    required String questionReference,
    required Map<String, dynamic> data,
  }) {
    final notes = data['notes'] as String?;
    final xFiles = data['images'] as List<XFile>?;
    final imagePaths = xFiles?.map((xFile) => xFile.path).toList() ?? [];

    return ObservationModel(
      formId: formId,
      questionReference: questionReference,
      notes: notes?.isEmpty ?? true ? null : notes,
      imagePaths: imagePaths,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to the format used by AppQuestionBlock
  /// `{notes: String, images: List<XFile>}`
  Map<String, dynamic> toQuestionBlockFormat() {
    return {
      'notes': notes ?? '',
      'images': imagePaths.map((path) => XFile(path)).toList(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'form_id': formId,
      'question_reference': questionReference,
      'notes': notes,
      'images': imagePaths,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ObservationModel copyWith({
    int? id,
    int? formId,
    String? questionReference,
    String? notes,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ObservationModel(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      questionReference: questionReference ?? this.questionReference,
      notes: notes ?? this.notes,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
