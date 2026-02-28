class CommunalControl {
  final int? id;
  final int formId;
  final String
  controlType; // BMS, Heating Controller, Sensors, Timer, Thermostat
  final String? location;
  final String? make;
  final String? model;
  final String? serialNumber;
  final String? condition; // Good, Fair, Poor, etc.
  final String? operational; // Yes, No
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunalControl({
    this.id,
    required this.formId,
    required this.controlType,
    this.location,
    this.make,
    this.model,
    this.serialNumber,
    this.condition,
    this.operational,
    this.imagePaths = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'form_id': formId,
      'control_type': controlType,
      'location': location,
      'make': make,
      'model': model,
      'serial_number': serialNumber,
      'condition': condition,
      'operational': operational,
      'image_paths': imagePaths.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CommunalControl.fromMap(Map<String, dynamic> map) {
    return CommunalControl(
      id: map['id'],
      formId: map['form_id'],
      controlType: map['control_type'],
      location: map['location'],
      make: map['make'],
      model: map['model'],
      serialNumber: map['serial_number'],
      condition: map['condition'],
      operational: map['operational'],
      imagePaths:
          map['image_paths'] != null && map['image_paths'].toString().isNotEmpty
          ? map['image_paths'].toString().split(',')
          : [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
