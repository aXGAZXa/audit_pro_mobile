import 'dart:convert';

class DwellingInspection {
  final int? id;
  final int formId;
  final String location; // e.g. Flat 42
  // Removed floor
  final String? heatingType;
  final String? heatGeneratorType;
  final String? heatGeneratorFuelType;
  final String? heatDistributionType;
  final String? dhwType;
  final String? dhwGeneratorType;
  final String? dhwGeneratorFuelType;
  final String? dhwCommunalType;
  final String? heatingMetered;
  final String? heatingSubMeterFeasible;
  final String? heatingSubMeterFeasibilityReason;
  final List<String> heatingSubMeterEvidenceImages; // Added
  final String? dhwMetered;
  final String? dhwSubMeterFeasible;
  final String? dhwSubMeterFeasibilityReason;
  final List<String> dhwSubMeterEvidenceImages; // Added

  // Tenant controls + supporting evidence (photos + notes)
  final List<String> heatingControls;
  final String? heatingControlsOther;
  final String? heatingNotes;
  final List<String> heatingImagePaths;
  final List<String> dhwControls;
  final String? dhwControlsOther;
  final String? dhwNotes;
  final List<String> dhwImagePaths;

  final String? hiuMake;
  final String? hiuModel;
  final String? hiuSerialNumber;
  final String? condition;
  final String? operational;
  final List<String> imagePaths;
  final DateTime? createdAt;
  final DateTime updatedAt;

  DwellingInspection({
    this.id,
    required this.formId,
    required this.location,
    this.heatingType,
    this.heatGeneratorType,
    this.heatGeneratorFuelType,
    this.heatDistributionType,
    this.dhwType,
    this.dhwGeneratorType,
    this.dhwGeneratorFuelType,
    this.dhwCommunalType,
    this.heatingMetered,
    this.heatingSubMeterFeasible,
    this.heatingSubMeterFeasibilityReason,
    this.heatingSubMeterEvidenceImages = const [],
    this.dhwMetered,
    this.dhwSubMeterFeasible,
    this.dhwSubMeterFeasibilityReason,
    this.dhwSubMeterEvidenceImages = const [],

    this.heatingControls = const [],
    this.heatingControlsOther,
    this.heatingNotes,
    this.heatingImagePaths = const [],
    this.dhwControls = const [],
    this.dhwControlsOther,
    this.dhwNotes,
    this.dhwImagePaths = const [],

    this.hiuMake,
    this.hiuModel,
    this.hiuSerialNumber,
    this.condition,
    this.operational,
    required this.imagePaths,
    this.createdAt,
    required this.updatedAt,
  });

  static String _encodeStringList(List<String> items) => jsonEncode(items);

  static List<String> _decodeStringList(dynamic value) {
    if (value == null) return const [];
    final raw = value.toString();
    if (raw.trim().isEmpty) return const [];

    // Prefer JSON (new fields) but tolerate legacy comma-separated strings.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .where((e) => e != null)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // ignore
    }

    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'form_id': formId,
      'location': location,
      'heating_type': heatingType,
      'heat_generator_type': heatGeneratorType,
      'heat_generator_fuel_type': heatGeneratorFuelType,
      'heat_distribution_type': heatDistributionType,
      'dhw_type': dhwType,
      'dhw_generator_type': dhwGeneratorType,
      'dhw_generator_fuel_type': dhwGeneratorFuelType,
      'dhw_communal_type': dhwCommunalType,
      'heating_metered': heatingMetered,
      'heating_sub_meter_feasible': heatingSubMeterFeasible,
      'heating_sub_meter_feasibility_reason': heatingSubMeterFeasibilityReason,
      'heating_sub_meter_evidence_images': heatingSubMeterEvidenceImages.join(
        ',',
      ),
      'dhw_metered': dhwMetered,
      'dhw_sub_meter_feasible': dhwSubMeterFeasible,
      'dhw_sub_meter_feasibility_reason': dhwSubMeterFeasibilityReason,
      'dhw_sub_meter_evidence_images': dhwSubMeterEvidenceImages.join(','),

      'heating_controls': _encodeStringList(heatingControls),
      'heating_controls_other': heatingControlsOther,
      'heating_notes': heatingNotes,
      'heating_image_paths': _encodeStringList(heatingImagePaths),
      'dhw_controls': _encodeStringList(dhwControls),
      'dhw_controls_other': dhwControlsOther,
      'dhw_notes': dhwNotes,
      'dhw_image_paths': _encodeStringList(dhwImagePaths),

      'hiu_make': hiuMake,
      'hiu_model': hiuModel,
      'hiu_serial_number': hiuSerialNumber,
      'condition': condition,
      'operational': operational,
      'image_paths': imagePaths.join(','),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DwellingInspection.fromMap(Map<String, dynamic> map) {
    return DwellingInspection(
      id: map['id'],
      formId: map['form_id'],
      location: map['location'],
      heatingType: map['heating_type'],
      heatGeneratorType: map['heat_generator_type'],
      heatGeneratorFuelType: map['heat_generator_fuel_type'],
      heatDistributionType: map['heat_distribution_type'],
      dhwType: map['dhw_type'],
      dhwGeneratorType: map['dhw_generator_type'],
      dhwGeneratorFuelType: map['dhw_generator_fuel_type'],
      dhwCommunalType: map['dhw_communal_type'],
      heatingMetered: map['heating_metered'],
      heatingSubMeterFeasible: map['heating_sub_meter_feasible'],
      heatingSubMeterFeasibilityReason:
          map['heating_sub_meter_feasibility_reason'],
      heatingSubMeterEvidenceImages:
          (map['heating_sub_meter_evidence_images'] as String?)
              ?.split(',')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      dhwMetered: map['dhw_metered'],
      dhwSubMeterFeasible: map['dhw_sub_meter_feasible'],
      dhwSubMeterFeasibilityReason: map['dhw_sub_meter_feasibility_reason'],
      dhwSubMeterEvidenceImages:
          (map['dhw_sub_meter_evidence_images'] as String?)
              ?.split(',')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],

      heatingControls: _decodeStringList(map['heating_controls']),
      heatingControlsOther: map['heating_controls_other'],
      heatingNotes: map['heating_notes'],
      heatingImagePaths: _decodeStringList(map['heating_image_paths']),
      dhwControls: _decodeStringList(map['dhw_controls']),
      dhwControlsOther: map['dhw_controls_other'],
      dhwNotes: map['dhw_notes'],
      dhwImagePaths: _decodeStringList(map['dhw_image_paths']),

      hiuMake: map['hiu_make'],
      hiuModel: map['hiu_model'],
      hiuSerialNumber: map['hiu_serial_number'],
      condition: map['condition'],
      operational: map['operational'],
      imagePaths:
          map['image_paths']
              ?.toString()
              .split(',')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
