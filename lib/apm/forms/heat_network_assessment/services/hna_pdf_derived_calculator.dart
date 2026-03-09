import 'package:audit_pro_mobile/apm/models/communal_control.dart';
import 'package:audit_pro_mobile/apm/models/dhw_plant.dart';
import 'package:audit_pro_mobile/apm/models/dwelling_inspection.dart';
import 'package:audit_pro_mobile/apm/models/heat_generator.dart';
import 'package:audit_pro_mobile/apm/models/heat_meter.dart';
import 'package:audit_pro_mobile/apm/models/plate_heat_exchanger.dart';

class HnaPdfDerivedCalculator {
  static const int schemaVersion = 1;

  static const List<String> _residentialNatureTypes = <String>[
    'Residential',
    'Care/Nursing Home',
    'Assisted Living',
    'Temporary Accomodation',
    'Sheltered Accomodation',
  ];

  /// Computes PDF-derived fields using the portal submission payload JSON.
  ///
  /// This is used by the Flutter web editor where we don't have access to the
  /// local SQLite-backed tables.
  ///
  /// Important: this is an adapter only; the derivation engine remains
  /// `compute(...)`.
  static Map<String, dynamic> computeFromPayload({
    required Map<String, dynamic> formData,
    required Map<String, dynamic> assetsJson,
    List<dynamic>? observationsJson,
    String methodologyVersion = 'v1',
  }) {
    final meters = _asListOfModel<HeatMeter>(
      assetsJson['heatMeters'],
      (m) => HeatMeter(
        id: _tryInt(m['id']),
        formId: 0,
        meterType: _getString(m, 'meterType'),
        make: _getString(m, 'make'),
        model: _getString(m, 'model'),
        location: _getString(m, 'location'),
        ageRange: _getString(m, 'ageRange'),
        serialNumber: _getStringOrNull(m, 'serialNumber'),
        operational: _getString(m, 'operational'),
        reading: _getStringOrNull(m, 'reading'),
        imagePaths: _getStringList(m, 'imagePaths'),
        relatedAssetType: _getStringOrNull(m, 'relatedAssetType'),
        relatedAssetId: _tryInt(m['relatedAssetId']),
        createdAt: _tryDate(m['createdAt']),
        updatedAt: _tryDate(m['updatedAt']),
      ),
    );

    final generators = _asListOfModel<HeatGenerator>(
      assetsJson['heatGenerators'],
      (g) => HeatGenerator(
        id: _tryInt(g['id']),
        formId: 0,
        generatorType: _getString(g, 'generatorType'),
        fuelType: _getString(g, 'fuelType'),
        location: _getString(g, 'location'),
        make: _getString(g, 'make'),
        model: _getString(g, 'model'),
        serialNumber: _getStringOrNull(g, 'serialNumber'),
        capacity: _getStringOrNull(g, 'capacity'),
        ageRange: _getString(g, 'ageRange'),
        condition: _getString(g, 'condition'),
        operational: _getStringOrNull(g, 'operational'),
        hasIndividualMeter: _getStringOrNull(g, 'hasIndividualMeter'),
        imagePaths: _getStringList(g, 'imagePaths'),
        createdAt: _tryDate(g['createdAt']),
        updatedAt: _tryDate(g['updatedAt']),
      ),
    );

    final phex = _asListOfModel<PlateHeatExchanger>(
      assetsJson['plateHeatExchangers'],
      (p) => PlateHeatExchanger(
        id: _tryInt(p['id']),
        formId: 0,
        location: _getString(p, 'location'),
        make: _getString(p, 'make'),
        model: _getString(p, 'model'),
        serialNumber: _getStringOrNull(p, 'serialNumber'),
        capacity: _getStringOrNull(p, 'capacity'),
        ageRange: _getString(p, 'ageRange'),
        condition: _getString(p, 'condition'),
        insulationCondition: _getStringOrNull(p, 'insulationCondition'),
        freeOfLeaks: _getStringOrNull(p, 'freeOfLeaks'),
        hasIsolationValves: _getStringOrNull(p, 'hasIsolationValves'),
        hasTempGauges: _getStringOrNull(p, 'hasTempGauges'),
        hasIndividualMeter: _getStringOrNull(p, 'hasIndividualMeter'),
        imagePaths: _getStringList(p, 'imagePaths'),
        createdAt: _tryDate(p['createdAt']),
        updatedAt: _tryDate(p['updatedAt']),
      ),
    );

    final dhwPlants = _asListOfModel<DhwPlant>(
      assetsJson['dhwPlants'],
      (p) => DhwPlant(
        id: _tryInt(p['id']),
        formId: 0,
        plantType: _getString(p, 'plantType'),
        fuelType: _getStringOrNull(p, 'fuelType'),
        location: _getString(p, 'location'),
        make: _getString(p, 'make'),
        model: _getString(p, 'model'),
        serialNumber: _getStringOrNull(p, 'serialNumber'),
        capacity: _getStringOrNull(p, 'capacity'),
        heatInput: _getStringOrNull(p, 'heatInput'),
        ageRange: _getString(p, 'ageRange'),
        condition: _getString(p, 'condition'),
        operational: _getStringOrNull(p, 'operational'),
        imagePaths: _getStringList(p, 'imagePaths'),
        createdAt: _tryDate(p['createdAt']),
        updatedAt: _tryDate(p['updatedAt']),
      ),
    );

    final communalControls = _asListOfModel<CommunalControl>(
      assetsJson['communalControls'],
      (c) => CommunalControl(
        id: _tryInt(c['id']),
        formId: 0,
        controlType: _getString(c, 'controlType'),
        location: _getStringOrNull(c, 'location'),
        make: _getStringOrNull(c, 'make'),
        model: _getStringOrNull(c, 'model'),
        serialNumber: _getStringOrNull(c, 'serialNumber'),
        condition: _getStringOrNull(c, 'condition'),
        operational: _getStringOrNull(c, 'operational'),
        imagePaths: _getStringList(c, 'imagePaths'),
        createdAt: _tryDate(c['createdAt']),
        updatedAt: _tryDate(c['updatedAt']),
      ),
    );

    final dwellingInspections = _asListOfModel<DwellingInspection>(
      assetsJson['dwellingInspections'],
      (d) => DwellingInspection(
        id: _tryInt(d['id']),
        formId: 0,
        location: _getString(d, 'location'),
        heatingType: _getStringOrNull(d, 'heatingType'),
        heatGeneratorType: _getStringOrNull(d, 'heatGeneratorType'),
        heatGeneratorFuelType: _getStringOrNull(d, 'heatGeneratorFuelType'),
        heatDistributionType: _getStringOrNull(d, 'heatDistributionType'),
        dhwType: _getStringOrNull(d, 'dhwType'),
        dhwGeneratorType: _getStringOrNull(d, 'dhwGeneratorType'),
        dhwGeneratorFuelType: _getStringOrNull(d, 'dhwGeneratorFuelType'),
        dhwCommunalType: _getStringOrNull(d, 'dhwCommunalType'),
        heatingMetered: _getStringOrNull(d, 'heatingMetered'),
        heatingSubMeterFeasible: _getStringOrNull(d, 'heatingSubMeterFeasible'),
        heatingSubMeterFeasibilityReason: _getStringOrNull(
          d,
          'heatingSubMeterFeasibilityReason',
        ),
        heatingSubMeterEvidenceImages: _getStringList(
          d,
          'heatingSubMeterEvidenceImages',
        ),
        dhwMetered: _getStringOrNull(d, 'dhwMetered'),
        dhwSubMeterFeasible: _getStringOrNull(d, 'dhwSubMeterFeasible'),
        dhwSubMeterFeasibilityReason: _getStringOrNull(
          d,
          'dhwSubMeterFeasibilityReason',
        ),
        dhwSubMeterEvidenceImages: _getStringList(
          d,
          'dhwSubMeterEvidenceImages',
        ),
        heatingControls: _getStringList(d, 'heatingControls'),
        heatingControlsOther: _getStringOrNull(d, 'heatingControlsOther'),
        heatingNotes: _getStringOrNull(d, 'heatingNotes'),
        heatingImagePaths: _getStringList(d, 'heatingImagePaths'),
        dhwControls: _getStringList(d, 'dhwControls'),
        dhwControlsOther: _getStringOrNull(d, 'dhwControlsOther'),
        dhwNotes: _getStringOrNull(d, 'dhwNotes'),
        dhwImagePaths: _getStringList(d, 'dhwImagePaths'),
        hiuMake: _getStringOrNull(d, 'hiuMake'),
        hiuModel: _getStringOrNull(d, 'hiuModel'),
        hiuSerialNumber: _getStringOrNull(d, 'hiuSerialNumber'),
        condition: _getStringOrNull(d, 'condition'),
        operational: _getStringOrNull(d, 'operational'),
        imagePaths: _getStringList(d, 'imagePaths'),
        createdAt: _tryDate(d['createdAt']),
        updatedAt: _tryDate(d['updatedAt']) ?? DateTime.now(),
      ),
    );

    return compute(
      formData: formData,
      meters: meters,
      generators: generators,
      phex: phex,
      dhwPlants: dhwPlants,
      communalControls: communalControls,
      dwellingInspections: dwellingInspections,
      observationsJson: observationsJson,
      methodologyVersion: methodologyVersion,
    );
  }

  static Map<String, dynamic> compute({
    required Map<String, dynamic> formData,
    required List<HeatMeter> meters,
    required List<HeatGenerator> generators,
    required List<PlateHeatExchanger> phex,
    required List<DhwPlant> dhwPlants,
    required List<CommunalControl> communalControls,
    required List<DwellingInspection> dwellingInspections,
    List<dynamic>? observationsJson,
    String methodologyVersion = 'v1',
  }) {
    final meetsHeatNetworkDefinitionRaw =
        (formData['meetsHeatNetworkDefinition'] ?? '').toString();

    final isDistrictNetwork =
        meetsHeatNetworkDefinitionRaw.trim().toLowerCase() ==
        'district heat network'.toLowerCase();
    final isCommunalNetwork =
        meetsHeatNetworkDefinitionRaw.trim().toLowerCase() ==
        'communal heat network'.toLowerCase();
    final isHeatNetwork = isDistrictNetwork || isCommunalNetwork;

    final numBlocks = _toInt(formData['numBlocks']) ?? 0;
    final numDwellings = _toInt(formData['numDwellings']) ?? 0;

    final hasBulkMeter = _toNullableBool(formData['hasBulkMeter']);
    final hasBlockMeters = _toNullableBool(formData['hasBlockMeters']);

    final bulkMeters = meters.where((m) => _isBulkMeterType(m.meterType));
    final blockMeters = meters.where((m) => _isBlockMeterType(m.meterType));

    final hasBulkMeters = bulkMeters.isNotEmpty;
    final hasBlockMetersAssets = blockMeters.isNotEmpty;
    final hasPhex = phex.isNotEmpty;
    final hasPlantAssets = generators.isNotEmpty || dhwPlants.isNotEmpty;

    final hasDwellingMeters = dwellingInspections.any(
      (i) => _equalsYes(i.heatingMetered) || _equalsYes(i.dhwMetered),
    );

    final meteringMessages = _buildMeteringMessages(
      isHeatNetwork: isHeatNetwork,
      isDistrictNetwork: isDistrictNetwork,
      isCommunalNetwork: isCommunalNetwork,
      numBlocks: numBlocks,
      hasBulkMeters: hasBulkMeters,
      hasBlockMeters: hasBlockMetersAssets,
      hasPhex: hasPhex,
      hasPlantAssets: hasPlantAssets,
      hasDwellingMeters: hasDwellingMeters,
    );

    final areDwellingInspectionsPossible = _equalsYes(
      formData['dwellingInspectionsPossible'],
    );

    final buildingNature = _toStringList(formData['buildingNature']);
    final isResidential = buildingNature.any(
      (e) => _residentialNatureTypes.contains(e.trim()),
    );

    final dwellingArrangementsConsistent =
        (formData['dwellingArrangementsConsistent'] ?? 'Unverified').toString();

    final heatSuppliedUnclearDetails =
        (formData['heatSuppliedUnclearDetails'] ?? '').toString();

    final supportedFacilities = _toStringList(formData['supportedFacilities']);
    final supportedFacilitiesOther =
        (formData['supportedFacilitiesOther'] ?? '').toString().trim();

    final supportedLivingIndicatorsRecorded =
        supportedFacilities.isNotEmpty || supportedFacilitiesOther.isNotEmpty;

    final hasBulkObserved = (hasBulkMeter == true) || hasBulkMeters;
    final hasBlockObserved = (hasBlockMeters == true) || hasBlockMetersAssets;

    final hasDwellingMetersObserved = hasDwellingMeters;
    final hasNonOperationalMeters = meters.any(
      (m) => !_isOperationalMeterState(m.operational),
    );
    final hasNonOperationalAssets =
        generators.any((g) => !_isOperationalAssetState(g.operational)) ||
        dhwPlants.any((p) => !_isOperationalAssetState(p.operational)) ||
        communalControls.any((c) => !_isOperationalAssetState(c.operational)) ||
        dwellingInspections.any(
          (d) => !_isOperationalAssetState(d.operational),
        );
    final hasOldMeters = meters.any((m) => _isTenPlusAgeRange(m.ageRange));
    final hasPoorConditionAssets =
        generators.any((g) => _isPoorCondition(g.condition)) ||
        phex.any((p) => _isPoorCondition(p.condition)) ||
        dhwPlants.any((p) => _isPoorCondition(p.condition)) ||
        communalControls.any((c) => _isPoorCondition(c.condition)) ||
        dwellingInspections.any((d) => _isPoorCondition(d.condition));
    final hasObservations = _hasAnyObservations(observationsJson);
    final hasUnsafeObservations = _hasAnyUnsafeObservations(observationsJson);

    final networkAgeCategory = _parseAgeCategory(
      (formData['approximateNetworkAge'] ?? '').toString(),
    );

    final triageNetworkClassificationSummary =
        _buildNetworkClassificationSummary(
          isDistrictNetwork: isDistrictNetwork,
          isCommunalNetwork: isCommunalNetwork,
          meetsHeatNetworkDefinitionRaw: meetsHeatNetworkDefinitionRaw,
        );

    final triageNetworkCategory = !isHeatNetwork
        ? ''
        : switch (networkAgeCategory) {
            _AgeCategory.under5 => 'Category 1: Under 5 years',
            _AgeCategory.fiveToTwenty => 'Category 2: 5–20 years',
            _AgeCategory.twentyPlus => 'Category 3: 20+ years',
            _AgeCategory.unknown => 'Network age category: Not stated',
          };

    final triageNetworkCategoryMeaning = !isHeatNetwork
        ? ''
        : switch (networkAgeCategory) {
            _AgeCategory.under5 =>
              'Recent networks are commonly treated as higher triage priority where key metering is not observed.',
            _AgeCategory.fiveToTwenty =>
              'Mid-life networks are commonly prioritised for further investigation and optimisation scoping.',
            _AgeCategory.twentyPlus =>
              'Legacy network: use condition-led appraisal to stage CAPEX decisions (targeted feasibility/options appraisal where risk/condition indicators justify it), and consider metering feasibility as part of a further study if network condition is found to be viable.',
            _AgeCategory.unknown =>
              'Network age banding is used for triage only; where not recorded, prioritisation relies on other observed factors.',
          };

    final dwellingFeasibilitySignal = _computeDwellingFeasibilitySignal(
      dwellingInspections,
    );

    final triageMeteringRiskSignals = _buildTriageMeteringRiskSignals(
      isHeatNetwork: isHeatNetwork,
      hasBulkObserved: hasBulkObserved,
      hasBlockObserved: hasBlockObserved,
      numBlocks: numBlocks,
      generators: generators,
      phex: phex,
      supportedLivingIndicatorsRecorded: supportedLivingIndicatorsRecorded,
      supportedFacilities: supportedFacilities,
      supportedFacilitiesOther: supportedFacilitiesOther,
      dwellingInspections: dwellingInspections,
      hasDwellingMetersObserved: hasDwellingMetersObserved,
      dwellingFeasibilitySignal: dwellingFeasibilitySignal,
      hasNonOperationalMeters: hasNonOperationalMeters,
      hasOldMeters: hasOldMeters,
    );

    final triageDwellingConsistencySignals =
        _buildTriageDwellingConsistencySignals(
          areDwellingInspectionsPossible: areDwellingInspectionsPossible,
          dwellingInspections: dwellingInspections,
          dwellingArrangementsConsistent: dwellingArrangementsConsistent,
          isResidential: isResidential,
        );

    final triageRegulatoryPreparednessSignals =
        _buildTriageRegulatoryPreparednessSignals(
          isHeatNetwork: isHeatNetwork,
          hasBulkObserved: hasBulkObserved,
          supportedLivingIndicatorsRecorded: supportedLivingIndicatorsRecorded,
          networkAgeCategory: networkAgeCategory,
          dwellingFeasibilitySignal: dwellingFeasibilitySignal,
          hasDwellingMetersObserved: hasDwellingMetersObserved,
          dwellingArrangementsConsistent: dwellingArrangementsConsistent,
          areDwellingInspectionsPossible: areDwellingInspectionsPossible,
          hasPoorConditionAssets: hasPoorConditionAssets,
          hasNonOperationalAssets: hasNonOperationalAssets,
          hasObservations: hasObservations,
          hasUnsafeObservations: hasUnsafeObservations,
        );

    final triageStrategicFramingFlags = _buildTriageStrategicFlags(
      isHeatNetwork: isHeatNetwork,
      hasBulkObserved: hasBulkObserved,
      hasDwellingMetersObserved: hasDwellingMetersObserved,
      dwellingFeasibilitySignal: dwellingFeasibilitySignal,
      areDwellingInspectionsPossible: areDwellingInspectionsPossible,
      dwellingArrangementsConsistent: dwellingArrangementsConsistent,
      heatSuppliedUnclearDetails: heatSuppliedUnclearDetails,
      hasPlantAssets:
          generators.isNotEmpty ||
          phex.isNotEmpty ||
          dhwPlants.isNotEmpty ||
          communalControls.isNotEmpty,
      networkAgeCategory: networkAgeCategory,
      hasNonOperationalAssets: hasNonOperationalAssets,
      hasObservations: hasObservations,
    );

    final triageConfidenceAndLimitations = _buildTriageConfidenceAndLimitations(
      areDwellingInspectionsPossible: areDwellingInspectionsPossible,
      numDwellings: numDwellings,
      buildingNature: buildingNature,
    );

    return {
      'schemaVersion': schemaVersion,
      'methodologyVersion': methodologyVersion,
      'computedAt': DateTime.now().toIso8601String(),
      'meteringMessages': meteringMessages,
      'triageNetworkClassificationSummary': triageNetworkClassificationSummary,
      'triageNetworkCategory': triageNetworkCategory,
      'triageNetworkCategoryMeaning': triageNetworkCategoryMeaning,
      'triageMeteringRiskSignals': triageMeteringRiskSignals,
      'triageDwellingConsistencySignals': triageDwellingConsistencySignals,
      'triageRegulatoryPreparednessSignals':
          triageRegulatoryPreparednessSignals,
      'triageStrategicFramingFlags': triageStrategicFramingFlags,
      'triageConfidenceAndLimitations': triageConfidenceAndLimitations,
      'triageVisualCaveatStatement': '',
    };
  }

  static List<T> _asListOfModel<T>(
    dynamic raw,
    T Function(Map<String, dynamic> m) builder,
  ) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      out.add(builder(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  static String _getString(Map<String, dynamic> m, String key) {
    final v = m[key];
    return (v ?? '').toString();
  }

  static String? _getStringOrNull(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    final s = v.toString();
    return s.trim().isEmpty ? null : s;
  }

  static List<String> _getStringList(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! List) return const <String>[];
    return v.where((e) => e != null).map((e) => e.toString()).toList();
  }

  static int? _tryInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static DateTime? _tryDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static List<String> _buildMeteringMessages({
    required bool isHeatNetwork,
    required bool isDistrictNetwork,
    required bool isCommunalNetwork,
    required int numBlocks,
    required bool hasBulkMeters,
    required bool hasBlockMeters,
    required bool hasPhex,
    required bool hasPlantAssets,
    required bool hasDwellingMeters,
  }) {
    if (!isHeatNetwork) return <String>[];

    final messages = <String>[];

    if ((isCommunalNetwork || isDistrictNetwork) && !hasBulkMeters) {
      messages.add(
        'No bulk meters were identified during the site inspection.',
      );
    }

    if (numBlocks > 1 && !hasBlockMeters) {
      messages.add(
        'No block level meters were identified during the site inspection.',
      );
    }

    if (isDistrictNetwork && !hasPhex) {
      messages.add(
        'No PHEX meters were identified during the site inspection.',
      );
    }

    if (isCommunalNetwork && hasPlantAssets && !hasBulkMeters) {
      messages.add(
        'No communal plant meters were identified during the site inspection.',
      );
    }

    if (!hasDwellingMeters) {
      messages.add(
        'No dwelling meters were identified during the site inspection.',
      );
    }

    return messages;
  }

  static String _buildNetworkClassificationSummary({
    required bool isDistrictNetwork,
    required bool isCommunalNetwork,
    required String meetsHeatNetworkDefinitionRaw,
  }) {
    if (isDistrictNetwork) {
      return 'This site was recorded as a District heat network.';
    }
    if (isCommunalNetwork) {
      return 'This site was recorded as a Communal heat network.';
    }

    final raw = meetsHeatNetworkDefinitionRaw.trim();
    if (raw.toLowerCase() == 'in-flat generation'.toLowerCase()) {
      return 'This site was recorded as not meeting the heat network definition because heat and/or DHW was supplied via in-flat generation only.';
    }
    if (raw.toLowerCase() == 'communal areas only'.toLowerCase()) {
      return 'This site was recorded as not meeting the heat network definition because heat and/or DHW was recorded as serving communal areas only.';
    }
    if (raw.toLowerCase() ==
        'shared accommodation (no separate premises)'.toLowerCase()) {
      return 'This site was recorded as not meeting the heat network definition because it was recorded as shared accommodation with no self-contained dwellings / separate premises.';
    }

    if (raw.isEmpty) {
      return 'This site was recorded as not meeting the heat network definition.';
    }

    return 'This site was recorded as: $raw.';
  }

  static List<String> _buildTriageMeteringRiskSignals({
    required bool isHeatNetwork,
    required bool hasBulkObserved,
    required bool hasBlockObserved,
    required int numBlocks,
    required List<HeatGenerator> generators,
    required List<PlateHeatExchanger> phex,
    required bool supportedLivingIndicatorsRecorded,
    required List<String> supportedFacilities,
    required String supportedFacilitiesOther,
    required List<DwellingInspection> dwellingInspections,
    required bool hasDwellingMetersObserved,
    required _DwellingFeasibilitySignal dwellingFeasibilitySignal,
    required bool hasNonOperationalMeters,
    required bool hasOldMeters,
  }) {
    final signals = <String>[];

    if (!isHeatNetwork) {
      signals.add(
        'This site was recorded as not meeting the heat network definition; heat network metering requirements do not apply. Monitor for regulatory changes and reassess if new evidence supports reclassification as a heat network.',
      );
      return signals;
    }

    if (supportedLivingIndicatorsRecorded) {
      final supportedList = supportedFacilities
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .join(', ');
      final supportedOther = supportedFacilitiesOther.trim();

      final details = <String>[];
      if (supportedList.isNotEmpty) details.add(supportedList);
      if (supportedOther.isNotEmpty) details.add(supportedOther);

      final detailText = details.isNotEmpty ? ' (${details.join('; ')})' : '';
      signals.add('Supported living indicators were recorded$detailText.');
    } else {
      signals.add('Supported living indicators were not recorded.');
    }

    signals.add(
      hasBulkObserved
          ? 'Bulk/inlet metering was observed or recorded.'
          : 'Bulk/inlet metering was not observed during the site inspection.',
    );

    if (_hasCommunalPlantAssetsWithoutMeters(generators, phex)) {
      signals.add(
        'No individual meters were recorded on the communal plant assets.',
      );
    }

    if (numBlocks > 1) {
      signals.add(
        hasBlockObserved
            ? 'Block-level metering was observed or recorded.'
            : 'Block-level metering was not observed during the site inspection.',
      );
    }

    signals.add(
      _buildDwellingMeteringRiskSignal(
        dwellingInspections: dwellingInspections,
        hasDwellingMetersObserved: hasDwellingMetersObserved,
        dwellingFeasibilitySignal: dwellingFeasibilitySignal,
      ),
    );

    if (hasNonOperationalMeters) {
      signals.add(
        'One or more meters were recorded as not operational; investigate functionality, confirm whether readings can be relied upon, and consider repair or replacement as required.',
      );
    }

    if (hasOldMeters) {
      signals.add(
        'One or more meters were recorded as over 10 years old; review manufacturer calibration and replacement recommendations and confirm whether recalibration and/or replacement is required.',
      );
    }

    return signals.toSet().toList();
  }

  static List<String> _buildTriageDwellingConsistencySignals({
    required bool areDwellingInspectionsPossible,
    required List<DwellingInspection> dwellingInspections,
    required String dwellingArrangementsConsistent,
    required bool isResidential,
  }) {
    final signals = <String>[];

    if (dwellingInspections.isEmpty && !isResidential) {
      signals.add(
        'No dwellings were recorded for this site; dwelling sampling is not applicable.',
      );
      return signals;
    }

    if (!areDwellingInspectionsPossible || dwellingInspections.isEmpty) {
      signals.add(
        'Heating/DHW dwelling arrangements (system configuration) could not be verified from the available evidence; further survey may be required where follow-on work depends on dwelling-level configuration.',
      );
      return signals;
    }

    if (dwellingArrangementsConsistent.trim().toLowerCase() == 'yes') {
      signals.add(
        'Sampled dwellings were recorded as consistent in their heating/DHW arrangements (system configuration). This does not mean metering feasibility is consistent across dwellings.',
      );
      return signals;
    }

    if (dwellingArrangementsConsistent.trim().toLowerCase() == 'no') {
      signals.add(
        'Variation was identified in heating/DHW arrangements (system configuration) within the dwelling sample.',
      );
      signals.add(
        'A wider survey may be required to confirm whether the observed variation is representative across the site.',
      );
      return signals;
    }

    signals.add(
      'Heating/DHW dwelling arrangements (system configuration) were not verified from the available sample.',
    );

    return signals;
  }

  static List<String> _buildTriageRegulatoryPreparednessSignals({
    required bool isHeatNetwork,
    required bool hasBulkObserved,
    required bool supportedLivingIndicatorsRecorded,
    required _AgeCategory networkAgeCategory,
    required _DwellingFeasibilitySignal dwellingFeasibilitySignal,
    required bool hasDwellingMetersObserved,
    required String dwellingArrangementsConsistent,
    required bool areDwellingInspectionsPossible,
    required bool hasPoorConditionAssets,
    required bool hasNonOperationalAssets,
    required bool hasObservations,
    required bool hasUnsafeObservations,
  }) {
    final signals = <String>[];
    final primaryPathway = _selectPrimaryTriagePathway(
      isHeatNetwork: isHeatNetwork,
      networkAgeCategory: networkAgeCategory,
      dwellingFeasibilitySignal: dwellingFeasibilitySignal,
      hasDwellingMetersObserved: hasDwellingMetersObserved,
      hasBulkObserved: hasBulkObserved,
    );
    final requiresWiderDwellingSampling = _needsWiderDwellingSampling(
      dwellingArrangementsConsistent: dwellingArrangementsConsistent,
      areDwellingInspectionsPossible: areDwellingInspectionsPossible,
    );
    final nonHeatNetworkMonitorSignal =
        'Monitor for regulatory changes and reassess classification if new evidence supports reclassification as a heat network.';

    switch (primaryPathway) {
      case _TriagePrimaryPathway.nonHeatNetwork:
        break;
      case _TriagePrimaryPathway.legacyConditionLed:
        signals.add(
          'Follow-on: carry out condition-led appraisal and targeted surveys to inform lifecycle decisions, confirm network condition, and identify whether the system remains a viable candidate for improvement works. Where the network is found to be viable, commission an optimisation/controls study to scope metering opportunities, funding alignment, and wider network improvements.',
        );
        signals.add(
          'Follow-on: monitor regulatory change and legacy-network retirement/replacement timelines so the forward plan can be updated as requirements develop.',
        );
      case _TriagePrimaryPathway.meteringImplementation:
        final bulkSignal = _buildBulkMeterPreparednessSignal(
          isHeatNetwork: isHeatNetwork,
          hasBulkObserved: hasBulkObserved,
          networkAgeCategory: networkAgeCategory,
        );
        if (bulkSignal != null) {
          signals.add(bulkSignal);
        }
        signals.add(
          'Follow-on: appoint a metering and billing specialist to confirm the approach and implement dwelling-level metering and billing where practicable.',
        );
      case _TriagePrimaryPathway.meteringFeasibilityStudy:
        final bulkSignal = _buildBulkMeterPreparednessSignal(
          isHeatNetwork: isHeatNetwork,
          hasBulkObserved: hasBulkObserved,
          networkAgeCategory: networkAgeCategory,
        );
        if (bulkSignal != null) {
          signals.add(bulkSignal);
        }
        signals.add(
          'Follow-on: further investigate and confirm feasibility for dwelling-level metering (targeted feasibility study to confirm constraints and options).',
        );
        signals.add(
          'Follow-on: where metering is confirmed as feasible, appoint a metering and billing specialist to confirm the approach and implement metering and billing where practicable.',
        );
      case _TriagePrimaryPathway.meteringPositionConfirmation:
        final bulkSignal = _buildBulkMeterPreparednessSignal(
          isHeatNetwork: isHeatNetwork,
          hasBulkObserved: hasBulkObserved,
          networkAgeCategory: networkAgeCategory,
        );
        if (bulkSignal != null) {
          signals.add(bulkSignal);
        }
        signals.add(
          'Follow-on: dwelling-level metering was not observed or could not be confirmed in the sample; confirm the site-wide position if this affects next steps.',
        );
      case _TriagePrimaryPathway.monitorAndRecord:
        if (dwellingFeasibilitySignal ==
                _DwellingFeasibilitySignal.notFeasible &&
            supportedLivingIndicatorsRecorded) {
          signals.add(
            'Follow-on: supported living indicators were recorded; ensure these are captured in the follow-on specialist review where relevant.',
          );
        }
    }

    if (isHeatNetwork && requiresWiderDwellingSampling) {
      signals.add(
        'Follow-on: widen dwelling sampling if site-wide assumptions are needed for the next stage.',
      );
    }

    final defectFollowOn = _buildConditionAndObservationFollowOn(
      hasPoorConditionAssets: hasPoorConditionAssets,
      hasNonOperationalAssets: hasNonOperationalAssets,
      hasObservations: hasObservations,
    );
    final unsafeFollowOn = hasUnsafeObservations
        ? 'Follow-on: unsafe observations were recorded; urgent investigation and remedial action should be arranged without delay in accordance with the recorded classification.'
        : null;

    if (!isHeatNetwork) {
      signals.add(
        _buildNonHeatNetworkFollowOn(
          defectFollowOn: defectFollowOn,
          unsafeFollowOn: unsafeFollowOn,
          monitorSignal: nonHeatNetworkMonitorSignal,
        ),
      );
      return signals.toSet().toList();
    }

    if (defectFollowOn != null) {
      signals.add(defectFollowOn);
    }

    if (unsafeFollowOn != null) {
      signals.add(unsafeFollowOn);
    }

    return signals.toSet().toList();
  }

  static _TriagePrimaryPathway _selectPrimaryTriagePathway({
    required bool isHeatNetwork,
    required _AgeCategory networkAgeCategory,
    required _DwellingFeasibilitySignal dwellingFeasibilitySignal,
    required bool hasDwellingMetersObserved,
    required bool hasBulkObserved,
  }) {
    if (!isHeatNetwork) {
      return _TriagePrimaryPathway.nonHeatNetwork;
    }

    if (networkAgeCategory == _AgeCategory.twentyPlus) {
      return _TriagePrimaryPathway.legacyConditionLed;
    }

    if (dwellingFeasibilitySignal ==
            _DwellingFeasibilitySignal.universallyFeasible &&
        !hasDwellingMetersObserved) {
      return _TriagePrimaryPathway.meteringImplementation;
    }

    if (dwellingFeasibilitySignal ==
        _DwellingFeasibilitySignal.mixedOrInconclusive) {
      return _TriagePrimaryPathway.meteringFeasibilityStudy;
    }

    if (!hasBulkObserved || !hasDwellingMetersObserved) {
      return _TriagePrimaryPathway.meteringPositionConfirmation;
    }

    return _TriagePrimaryPathway.monitorAndRecord;
  }

  static bool _needsWiderDwellingSampling({
    required String dwellingArrangementsConsistent,
    required bool areDwellingInspectionsPossible,
  }) {
    return dwellingArrangementsConsistent.trim().toLowerCase() == 'no' ||
        !areDwellingInspectionsPossible;
  }

  static String? _buildBulkMeterPreparednessSignal({
    required bool isHeatNetwork,
    required bool hasBulkObserved,
    required _AgeCategory networkAgeCategory,
  }) {
    if (!isHeatNetwork || hasBulkObserved) {
      return null;
    }

    final qualifier = switch (networkAgeCategory) {
      _AgeCategory.under5 =>
        'For a recently recorded network, this should be treated as a higher priority.',
      _AgeCategory.twentyPlus =>
        'For a legacy network, prioritise condition-led surveys first so viability, remaining service life, and current topology are understood before metering follow-on work is commissioned.',
      _ =>
        'This may warrant prioritised follow-on review of metering topology.',
    };

    return 'Bulk/inlet metering was not observed. $qualifier';
  }

  static String? _buildConditionAndObservationFollowOn({
    required bool hasPoorConditionAssets,
    required bool hasNonOperationalAssets,
    required bool hasObservations,
  }) {
    if (hasPoorConditionAssets && hasNonOperationalAssets && hasObservations) {
      return 'Follow-on: poor or very poor condition assets, non-operational assets, and related inspection issues were recorded; commission a condition survey/report and investigate the recorded defects to confirm remaining service life, identify faults, restore operation where practicable, and inform repair or replacement requirements.';
    }

    if (hasPoorConditionAssets && hasObservations) {
      return 'Follow-on: poor or very poor condition assets and related inspection issues were recorded; commission a condition survey/report and investigate the recorded defects to confirm remaining service life, identify faults, and inform repair or replacement requirements.';
    }

    if (hasNonOperationalAssets && hasObservations) {
      return 'Follow-on: non-operational assets and related inspection issues were recorded; investigate the recorded defects, confirm root causes and remaining serviceability, and plan repair, reinstatement, or replacement as appropriate.';
    }

    if (hasPoorConditionAssets) {
      return 'Follow-on: one or more assets were recorded in poor or very poor condition; commission a condition survey/report as a higher priority to confirm remaining service life, identify defects, and inform repair or replacement requirements.';
    }

    if (hasNonOperationalAssets) {
      return 'Follow-on: one or more assets were recorded as non-operational; investigate the cause, confirm whether service can be safely restored, and plan repair or replacement as appropriate.';
    }

    if (hasObservations) {
      return 'Follow-on: issues were recorded in the inspection observations; review, investigate, and rectify these items as appropriate.';
    }

    return null;
  }

  static String _buildNonHeatNetworkFollowOn({
    required String? defectFollowOn,
    required String? unsafeFollowOn,
    required String monitorSignal,
  }) {
    final parts = <String>[];

    if (defectFollowOn != null && defectFollowOn.trim().isNotEmpty) {
      parts.add(defectFollowOn.trim());
    }
    if (unsafeFollowOn != null && unsafeFollowOn.trim().isNotEmpty) {
      parts.add(unsafeFollowOn.trim());
    }

    parts.add(monitorSignal);
    return parts.join(' ');
  }

  static bool _isOperationalMeterState(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'yes' || normalized == 'operational';
  }

  static bool _isOperationalAssetState(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return normalized == 'yes' ||
        normalized == 'operational' ||
        normalized == 'true';
  }

  static bool _isTenPlusAgeRange(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('10 plus') ||
        normalized.contains('10+') ||
        normalized.contains('10-20') ||
        normalized.contains('10 - 20') ||
        normalized.contains('20+') ||
        normalized.contains('20 plus');
  }

  static bool _isPoorCondition(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'poor' || normalized == 'very poor';
  }

  static bool _hasAnyObservations(List<dynamic>? observationsJson) {
    if (observationsJson == null) return false;
    for (final item in observationsJson) {
      if (item is! Map) continue;
      return true;
    }
    return false;
  }

  static bool _hasAnyUnsafeObservations(List<dynamic>? observationsJson) {
    if (observationsJson == null) return false;
    for (final item in observationsJson) {
      if (item is! Map) continue;
      final observation = Map<String, dynamic>.from(item);
      final raw = observation['is_unsafe'] ?? observation['isUnsafe'];
      if (raw == true || raw == 1) return true;
      final asText = (raw ?? '').toString().trim().toLowerCase();
      if (asText == 'true' || asText == '1' || asText == 'yes') return true;
      final classification =
          (observation['unsafe_classification'] ??
                  observation['unsafeClassification'] ??
                  '')
              .toString()
              .trim();
      if (classification.isNotEmpty) return true;
    }
    return false;
  }

  static List<String> _buildTriageStrategicFlags({
    required bool isHeatNetwork,
    required bool hasBulkObserved,
    required bool hasDwellingMetersObserved,
    required _DwellingFeasibilitySignal dwellingFeasibilitySignal,
    required bool areDwellingInspectionsPossible,
    required String dwellingArrangementsConsistent,
    required String heatSuppliedUnclearDetails,
    required bool hasPlantAssets,
    required _AgeCategory networkAgeCategory,
    required bool hasNonOperationalAssets,
    required bool hasObservations,
  }) {
    final flags = <String>[];

    if (!isHeatNetwork) {
      if (hasNonOperationalAssets || hasObservations) {
        flags.add('Asset issues recorded');
      } else {
        flags.add('Monitor for regulatory changes');
      }
      return flags;
    }

    final hasMeteringGaps =
        !hasBulkObserved ||
        (!hasDwellingMetersObserved &&
            dwellingFeasibilitySignal ==
                _DwellingFeasibilitySignal.universallyFeasible);

    if (hasMeteringGaps) {
      if (networkAgeCategory == _AgeCategory.twentyPlus) {
        flags.add('Metering gaps recorded');
      } else {
        flags.add('Metering review prioritised');
      }
    }

    if (!areDwellingInspectionsPossible ||
        dwellingArrangementsConsistent.trim().toLowerCase() == 'no' ||
        heatSuppliedUnclearDetails.trim().isNotEmpty) {
      flags.add('Further investigation recommended');
    }

    if (dwellingFeasibilitySignal ==
        _DwellingFeasibilitySignal.mixedOrInconclusive) {
      flags.add('Further investigation recommended');
    }

    if (isHeatNetwork &&
        networkAgeCategory == _AgeCategory.fiveToTwenty &&
        hasPlantAssets) {
      flags.add('Optimisation candidate');
    }

    if (isHeatNetwork && networkAgeCategory == _AgeCategory.twentyPlus) {
      flags.add('Legacy: staged lifecycle decisions');
    }

    if (hasObservations) {
      flags.add('Observations recorded');
    }

    if (flags.isEmpty) {
      flags.add('Monitor and record');
    }

    // De-duplicate (without re-ordering) so badges don't repeat.
    return flags.toSet().toList();
  }

  static _DwellingFeasibilitySignal _computeDwellingFeasibilitySignal(
    List<DwellingInspection> inspections,
  ) {
    if (inspections.isEmpty) return _DwellingFeasibilitySignal.notRecorded;

    String normalizeYesNoUnknown(String? value) {
      final v = value?.trim();
      if (v == null || v.isEmpty) return '';
      final lower = v.toLowerCase();
      if (lower == 'yes') return 'Yes';
      if (lower == 'no') return 'No';
      if (lower == 'unknown' ||
          lower.contains('further investigation') ||
          lower.contains('investigation required') ||
          lower.contains('investigation needed')) {
        return 'Unknown';
      }
      return '';
    }

    final normalized = <String>[];
    for (final inspection in inspections) {
      final heating = normalizeYesNoUnknown(inspection.heatingSubMeterFeasible);
      final dhw = normalizeYesNoUnknown(inspection.dhwSubMeterFeasible);
      if (heating.isNotEmpty) normalized.add(heating);
      if (dhw.isNotEmpty) normalized.add(dhw);
    }

    if (normalized.isEmpty) return _DwellingFeasibilitySignal.notRecorded;

    final hasYes = normalized.any((v) => v == 'Yes');
    final hasNo = normalized.any((v) => v == 'No');
    final hasUnknown = normalized.any((v) => v == 'Unknown');

    if (hasUnknown) {
      return (hasYes || hasNo)
          ? _DwellingFeasibilitySignal.mixedOrInconclusive
          : _DwellingFeasibilitySignal.notRecorded;
    }

    if (hasYes && hasNo) return _DwellingFeasibilitySignal.mixedOrInconclusive;
    if (hasYes) return _DwellingFeasibilitySignal.universallyFeasible;
    if (hasNo) return _DwellingFeasibilitySignal.notFeasible;

    return _DwellingFeasibilitySignal.notRecorded;
  }

  static bool _hasCommunalPlantAssetsWithoutMeters(
    List<HeatGenerator> generators,
    List<PlateHeatExchanger> phex,
  ) {
    final plantMeterStates = <String?>[
      ...generators.map((g) => g.hasIndividualMeter),
      ...phex.map((p) => p.hasIndividualMeter),
    ];

    if (plantMeterStates.isEmpty) return false;

    final hasMeteredPlant = plantMeterStates.any(_isYesValue);
    final hasExplicitUnmeteredPlant = plantMeterStates.any(_isNoValue);
    return !hasMeteredPlant && hasExplicitUnmeteredPlant;
  }

  static String _buildDwellingMeteringRiskSignal({
    required List<DwellingInspection> dwellingInspections,
    required bool hasDwellingMetersObserved,
    required _DwellingFeasibilitySignal dwellingFeasibilitySignal,
  }) {
    if (dwellingInspections.isEmpty) {
      return 'Dwelling-level metering could not be confirmed due to limited access and/or inspection limitations.';
    }

    if (hasDwellingMetersObserved) {
      return switch (dwellingFeasibilitySignal) {
        _DwellingFeasibilitySignal.mixedOrInconclusive =>
          'Dwelling-level metering was observed in parts of the dwelling sample, but wider feasibility was mixed or requires further investigation.',
        _DwellingFeasibilitySignal.notFeasible =>
          'Dwelling-level metering was observed in the sampled dwellings, but wider implementation was recorded as not feasible based on the dwelling sample.',
        _ => 'Dwelling-level metering was observed in the sampled dwellings.',
      };
    }

    return switch (dwellingFeasibilitySignal) {
      _DwellingFeasibilitySignal.universallyFeasible =>
        'Dwelling-level metering was not observed in the sampled dwellings, but was recorded as potentially feasible based on the dwelling sample.',
      _DwellingFeasibilitySignal.notFeasible =>
        'Dwelling-level metering was not observed in the sampled dwellings and was recorded as not feasible based on the dwelling sample.',
      _DwellingFeasibilitySignal.mixedOrInconclusive =>
        'Dwelling-level metering was not observed in the sampled dwellings; feasibility was mixed or requires further investigation based on the dwelling sample.',
      _DwellingFeasibilitySignal.notRecorded =>
        'Dwelling-level metering was not observed in the sampled dwellings; feasibility was not recorded.',
    };
  }

  static bool _isYesValue(String? value) =>
      (value ?? '').trim().toLowerCase() == 'yes';

  static bool _isNoValue(String? value) =>
      (value ?? '').trim().toLowerCase() == 'no';

  static String _buildTriageConfidenceAndLimitations({
    required bool areDwellingInspectionsPossible,
    required int numDwellings,
    required List<String> buildingNature,
  }) {
    final parts = <String>[
      'This summary is based on a visual site inspection and the information reasonably visible or accessible on the day.',
      'Where building age and network age are stated, they reflect recorded estimates.',
      'It does not constitute a detailed technical assessment, compliance determination, or performance review.',
    ];

    final inferredResidential = buildingNature.any(
      (value) => _residentialNatureTypes.contains(value.trim()),
    );
    final hasNoRecordedDwellings = !inferredResidential && numDwellings <= 0;

    if (hasNoRecordedDwellings) {
      parts.add(
        'No dwellings were recorded for this site; dwelling sampling is not applicable.',
      );
      return parts.join(' ');
    }

    if (!areDwellingInspectionsPossible) {
      parts.add(
        'Dwelling sampling was limited by access constraints and may not be representative of the full site.',
      );
    }

    return parts.join(' ');
  }

  static _AgeCategory _parseAgeCategory(String value) {
    final v = value.trim();
    if (v.isEmpty) return _AgeCategory.unknown;

    final lower = v.toLowerCase();

    if (lower.contains('under 5') ||
        lower.contains('up to 5') ||
        lower.contains('<5')) {
      return _AgeCategory.under5;
    }

    if (lower.contains('5') &&
        (lower.contains('20') || lower.contains('20 years'))) {
      return _AgeCategory.fiveToTwenty;
    }

    if (lower.contains('20+') ||
        lower.contains('20 plus') ||
        lower.contains('20 years +') ||
        (lower.contains('20 years') && lower.contains('+'))) {
      return _AgeCategory.twentyPlus;
    }

    if (lower.contains('20') && lower.contains('+')) {
      return _AgeCategory.twentyPlus;
    }

    return _AgeCategory.unknown;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool? _toNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();
    if (text == 'yes' || text == 'true' || text == 'y') return true;
    if (text == 'no' || text == 'false' || text == 'n') return false;

    return null;
  }

  static bool _equalsYes(dynamic value) =>
      value?.toString().trim().toLowerCase() == 'yes';

  static bool _isBulkMeterType(String value) =>
      value.toLowerCase().contains('bulk') ||
      value.toLowerCase().contains('inlet');

  static bool _isBlockMeterType(String value) =>
      value.toLowerCase().contains('block');

  static List<String> _toStringList(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value
          .where((v) => v != null)
          .map((v) => v.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}

enum _AgeCategory { unknown, under5, fiveToTwenty, twentyPlus }

enum _DwellingFeasibilitySignal {
  notRecorded,
  universallyFeasible,
  notFeasible,
  mixedOrInconclusive,
}

enum _TriagePrimaryPathway {
  nonHeatNetwork,
  legacyConditionLed,
  meteringImplementation,
  meteringFeasibilityStudy,
  meteringPositionConfirmation,
  monitorAndRecord,
}
