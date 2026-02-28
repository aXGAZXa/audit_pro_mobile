class HeatGenerator {
  final int? id;
  final int formId;
  final String generatorType; // Boiler, Water Heater, etc.
  final String fuelType; // Gas, Oil, etc.
  final String location;
  final String make;
  final String model;
  final String? serialNumber;
  final String? capacity;
  final String ageRange;
  final String condition;
  final String? operational; // Changed from insulationCondition
  final String? hasIndividualMeter; // Yes/No
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  HeatGenerator({
    this.id,
    required this.formId,
    required this.generatorType,
    required this.fuelType,
    required this.location,
    required this.make,
    required this.model,
    this.serialNumber,
    this.capacity,
    required this.ageRange,
    required this.condition,
    this.operational,
    this.hasIndividualMeter,
    this.imagePaths = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'form_id': formId,
      'generator_type': generatorType,
      'fuel_type': fuelType,
      'location': location,
      'make': make,
      'model': model,
      'serial_number': serialNumber,
      'capacity': capacity,
      'age_range': ageRange,
      'condition': condition,
      'operational': operational,
      'has_individual_meter': hasIndividualMeter,
      'image_paths': imagePaths.join(','), // Simple comma-separated list for DB
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HeatGenerator.fromMap(Map<String, dynamic> map) {
    return HeatGenerator(
      id: map['id'],
      formId: map['form_id'],
      generatorType: map['generator_type'],
      fuelType: map['fuel_type'],
      location: map['location'],
      make: map['make'],
      model: map['model'],
      serialNumber: map['serial_number'],
      capacity: map['capacity'],
      ageRange: map['age_range'],
      condition: map['condition'],
      operational: map['operational'],
      hasIndividualMeter: map['has_individual_meter'],
      imagePaths:
          map['image_paths'] != null && map['image_paths'].toString().isNotEmpty
          ? map['image_paths'].toString().split(',')
          : [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
