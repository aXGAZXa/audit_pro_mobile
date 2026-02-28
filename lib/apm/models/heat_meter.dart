class HeatMeter {
  final int? id;
  final int formId;
  final String meterType;
  final String make;
  final String model;
  final String location;
  final String ageRange;
  final String? serialNumber;
  final String operational; // 'YES' or 'NO'
  final String? reading;
  final List<String> imagePaths;
  final String? relatedAssetType;
  final int? relatedAssetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  HeatMeter({
    this.id,
    required this.formId,
    required this.meterType,
    required this.make,
    required this.model,
    required this.location,
    required this.ageRange,
    this.serialNumber,
    required this.operational,
    this.reading,
    this.imagePaths = const [],
    this.relatedAssetType,
    this.relatedAssetId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'form_id': formId,
      'meter_type': meterType,
      'make': make,
      'model': model,
      'location': location,
      'age_range': ageRange,
      'serial_number': serialNumber,
      'operational': operational,
      'reading': reading,
      'related_asset_type': relatedAssetType,
      'related_asset_id': relatedAssetId,
      'image_paths': imagePaths.isEmpty
          ? null
          : imagePaths.join(','), // Simple comma separated or JSON?
      // Existing app likely uses JSON or comma separated.
      // Looking at previous code: `imagePaths` was passed to savedAsset.
      // Assets table doesn't have image column, it has `asset_images` table.
      // But for this standalone model, let's keep it simple. User said generic standalone.
      // Let's check how images were handled in assets: `imagePaths: imagePaths.isEmpty ? null : imagePaths`
      // DB Helper saved them to `asset_images` table.
      // For HeatMeter, let's just use a text column for simplicity if it's 1 image, or a separate table.
      // Given user wants "Data Model", I will stick to a clean table `heat_meters`.
      // I will store images as a JSON string or comma separated string in the table for simplicity,
      // or create `heat_meter_images` table.
      // Given "max 1 image", a column `image_path` is sufficient.
      // But UI uses list. I will assume `image_paths` TEXT column (JSON List)
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HeatMeter.fromMap(Map<String, dynamic> map) {
    return HeatMeter(
      id: map['id'] as int?,
      formId: map['form_id'] as int,
      meterType: map['meter_type'] as String,
      make: map['make'] as String,
      model: map['model'] as String,
      location: map['location'] as String,
      ageRange: map['age_range'] as String,
      serialNumber: map['serial_number'] as String?,
      operational: map['operational'] as String,
      reading: map['reading'] as String?,
      relatedAssetType: map['related_asset_type'] as String?,
      relatedAssetId: map['related_asset_id'] as int?,
      imagePaths: map['image_paths'] != null
          ? (map['image_paths'] as String).split(',')
          : [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  HeatMeter copyWith({
    int? id,
    int? formId,
    String? meterType,
    String? make,
    String? model,
    String? location,
    String? ageRange,
    String? serialNumber,
    String? operational,
    String? reading,
    String? relatedAssetType,
    int? relatedAssetId,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HeatMeter(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      meterType: meterType ?? this.meterType,
      make: make ?? this.make,
      model: model ?? this.model,
      location: location ?? this.location,
      ageRange: ageRange ?? this.ageRange,
      serialNumber: serialNumber ?? this.serialNumber,
      operational: operational ?? this.operational,
      reading: reading ?? this.reading,
      relatedAssetType: relatedAssetType ?? this.relatedAssetType,
      relatedAssetId: relatedAssetId ?? this.relatedAssetId,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
