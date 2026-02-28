class DhwPlant {
  final int? id;
  final int formId;
  final String plantType; // Calorifier, DHW heater, etc.
  final String? fuelType; // Only relevant for DHW heater (e.g. Gas, Electric)
  final String location;
  final String make;
  final String model;
  final String? serialNumber;
  final String? capacity; // Optional
  final String? heatInput; // Optional
  final String ageRange;
  final String condition;
  final String? operational;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  DhwPlant({
    this.id,
    required this.formId,
    required this.plantType,
    this.fuelType,
    required this.location,
    required this.make,
    required this.model,
    this.serialNumber,
    this.capacity,
    this.heatInput,
    required this.ageRange,
    required this.condition,
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
      'plant_type': plantType,
      'fuel_type': fuelType,
      'location': location,
      'make': make,
      'model': model,
      'serial_number': serialNumber,
      'capacity': capacity,
      'heat_input': heatInput,
      'age_range': ageRange,
      'condition': condition,
      'operational': operational,
      'image_paths': imagePaths.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DhwPlant.fromMap(Map<String, dynamic> map) {
    return DhwPlant(
      id: map['id'],
      formId: map['form_id'],
      plantType: map['plant_type'],
      fuelType: map['fuel_type'],
      location: map['location'],
      make: map['make'],
      model: map['model'],
      serialNumber: map['serial_number'],
      capacity: map['capacity'],
      heatInput: map['heat_input'],
      ageRange: map['age_range'],
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
