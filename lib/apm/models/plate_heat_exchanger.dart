class PlateHeatExchanger {
  final int? id;
  final int formId;
  final String location;
  final String make;
  final String model;
  final String? serialNumber;
  final String? capacity;
  final String ageRange;
  final String condition;
  final String? insulationCondition;
  final String? freeOfLeaks;
  final String? hasIsolationValves;
  final String? hasTempGauges;
  final String? hasIndividualMeter;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlateHeatExchanger({
    this.id,
    required this.formId,
    required this.location,
    required this.make,
    required this.model,
    this.serialNumber,
    this.capacity,
    required this.ageRange,
    required this.condition,
    this.insulationCondition,
    this.freeOfLeaks,
    this.hasIsolationValves,
    this.hasTempGauges,
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
      'location': location,
      'make': make,
      'model': model,
      'serial_number': serialNumber,
      'capacity': capacity,
      'age_range': ageRange,
      'condition': condition,
      'insulation_condition': insulationCondition,
      'free_of_leaks': freeOfLeaks,
      'has_isolation_valves': hasIsolationValves,
      'has_temp_gauges': hasTempGauges,
      'has_individual_meter': hasIndividualMeter,
      'image_paths': imagePaths.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PlateHeatExchanger.fromMap(Map<String, dynamic> map) {
    return PlateHeatExchanger(
      id: map['id'],
      formId: map['form_id'],
      location: map['location'],
      make: map['make'],
      model: map['model'],
      serialNumber: map['serial_number'],
      capacity: map['capacity'],
      ageRange: map['age_range'],
      condition: map['condition'],
      insulationCondition: map['insulation_condition'],
      freeOfLeaks: map['free_of_leaks'],
      hasIsolationValves: map['has_isolation_valves'],
      hasTempGauges: map['has_temp_gauges'],
      hasIndividualMeter: map['has_individual_meter'],
      imagePaths: map['image_paths'] != null && map['image_paths'].isNotEmpty
          ? (map['image_paths'] as String).split(',') // Safe split
          : [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
