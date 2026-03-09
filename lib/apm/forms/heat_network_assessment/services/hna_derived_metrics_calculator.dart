class HnaDerivedMetricsCalculator {
  static const int schemaVersion = 3;

  /// Computes derived metrics using only the submission payload JSON.
  ///
  /// This is used by HNA submission building and the Flutter web editor.
  /// It intentionally avoids all SQLite per-asset tables.
  static Map<String, dynamic> computeFromPayload({
    required Map<String, dynamic> formData,
    Map<String, dynamic>? assetsJson,
    List<dynamic>? observationsJson,
    Map<String, dynamic>? unsafeJson,
    String methodologyVersion = 'v1',
  }) {
    final meters = _asListOfMaps(assetsJson?['heatMeters']);
    final generators = _asListOfMaps(assetsJson?['heatGenerators']);
    final phex = _asListOfMaps(assetsJson?['plateHeatExchangers']);
    final dhwPlants = _asListOfMaps(assetsJson?['dhwPlants']);
    final communalControls = _asListOfMaps(assetsJson?['communalControls']);
    final dwellingInspections = _asListOfMaps(
      assetsJson?['dwellingInspections'],
    );

    final observations = _asListOfMapsFromDynamicList(observationsJson);
    final unsafeObservations = _asListOfMaps(unsafeJson?['unsafeObservations']);

    final networkType = _normalizeNetworkType(
      formData['meetsHeatNetworkDefinition'],
    );
    final isHeatNetwork =
        networkType == 'district' || networkType == 'communal';
    final suppliesDwellings = switch (networkType) {
      'communal_areas_only' => false,
      'shared_accommodation_no_separate_premises' => false,
      _ => true,
    };
    final numBlocks = _toInt(formData['numBlocks']) ?? 0;

    final totalMeterCount = meters.length;
    final bulkMeterCount = meters
        .where((m) => _isBulkMeterType((m['meterType'] ?? '').toString()))
        .length;
    final blockMeterCount = meters
        .where((m) => _isBlockMeterType((m['meterType'] ?? '').toString()))
        .length;

    // Generator metering expectations:
    // - Communal heat networks: we expect generator assets to be recorded, and each generator to have individual metering evidence.
    // - District heat networks: on-site generators may not exist, so generator metering is not required when none are recorded.
    final allGeneratorsHaveIndividualMeters = networkType == 'communal'
        ? (generators.isNotEmpty &&
              generators.every((g) => _equalsYes(g['hasIndividualMeter'])))
        : (generators.isEmpty
              ? true
              : generators.every((g) => _equalsYes(g['hasIndividualMeter'])));

    final allInspectedDwellingsMetered = !suppliesDwellings
        ? true
        : dwellingInspections.isNotEmpty &&
              dwellingInspections.every((d) {
                final heatingMetered = (d['heatingMetered'] ?? '').toString();
                final dhwMetered = (d['dhwMetered'] ?? '').toString();
                return _equalsYes(heatingMetered) || _equalsYes(dhwMetered);
              });

    final anyInspectedDwellingMetered = !suppliesDwellings
        ? false
        : dwellingInspections.any((d) {
            final heatingMetered = (d['heatingMetered'] ?? '').toString();
            final dhwMetered = (d['dhwMetered'] ?? '').toString();
            return _equalsYes(heatingMetered) || _equalsYes(dhwMetered);
          });

    final anyGeneratorHasIndividualMeter = generators.any(
      (g) => _equalsYes(g['hasIndividualMeter']),
    );

    final plantInPoorCondition = _countPlantItemsInPoorConditionJson(
      generators: generators,
      phex: phex,
      dhwPlants: dhwPlants,
      communalControls: communalControls,
    );

    final assistedLivingIndicators = _countAssistedLivingIndicators(formData);
    final buildingUseCases = _buildBuildingUseCases(formData);

    final meteringProvided = _computeMeteringProvided(
      isHeatNetwork: isHeatNetwork,
      suppliesDwellings: suppliesDwellings,
      numBlocks: numBlocks,
      totalMeterCount: totalMeterCount,
      bulkMeterCount: bulkMeterCount,
      blockMeterCount: blockMeterCount,
      allGeneratorsHaveIndividualMeters: allGeneratorsHaveIndividualMeters,
      allInspectedDwellingsMetered: allInspectedDwellingsMetered,
      anyInspectedDwellingMetered: anyInspectedDwellingMetered,
      anyGeneratorHasIndividualMeter: anyGeneratorHasIndividualMeter,
      hasBulkMeter: _toNullableBool(formData['hasBulkMeter']),
      hasBlockMeters: _toNullableBool(formData['hasBlockMeters']),
    );

    final dwellingMeteringFeasibility =
        _computeDwellingMeteringFeasibilityFromInspectionsJson(
          isHeatNetwork: isHeatNetwork,
          suppliesDwellings: suppliesDwellings,
          meteringProvided: meteringProvided,
          dwellingInspections: dwellingInspections,
        );

    return _computeCore(
      formData: formData,
      isHeatNetwork: isHeatNetwork,
      suppliesDwellings: suppliesDwellings,
      numBlocks: numBlocks,
      totalMeterCount: totalMeterCount,
      bulkMeterCount: bulkMeterCount,
      blockMeterCount: blockMeterCount,
      allGeneratorsHaveIndividualMeters: allGeneratorsHaveIndividualMeters,
      allInspectedDwellingsMetered: allInspectedDwellingsMetered,
      anyInspectedDwellingMetered: anyInspectedDwellingMetered,
      anyGeneratorHasIndividualMeter: anyGeneratorHasIndividualMeter,
      numberOfDwellingsInspected: dwellingInspections.length,
      plantInPoorCondition: plantInPoorCondition,
      assistedLivingIndicators: assistedLivingIndicators,
      buildingUseCases: buildingUseCases,
      dwellingMeteringFeasibility: dwellingMeteringFeasibility,
      observationCount: observations.length,
      unsafeCount: unsafeObservations.length,
      methodologyVersion: methodologyVersion,
    );
  }

  static Map<String, dynamic> _computeCore({
    required Map<String, dynamic> formData,
    required bool isHeatNetwork,
    required bool suppliesDwellings,
    required int numBlocks,
    required int totalMeterCount,
    required int bulkMeterCount,
    required int blockMeterCount,
    required bool allGeneratorsHaveIndividualMeters,
    required bool allInspectedDwellingsMetered,
    required bool anyInspectedDwellingMetered,
    required bool anyGeneratorHasIndividualMeter,
    required int numberOfDwellingsInspected,
    required int plantInPoorCondition,
    required int assistedLivingIndicators,
    required String buildingUseCases,
    required String dwellingMeteringFeasibility,
    required int observationCount,
    required int unsafeCount,
    required String methodologyVersion,
  }) {
    final networkClassification = (formData['meetsHeatNetworkDefinition'] ?? '')
        .toString();

    final hasBulkMeter = _toNullableBool(formData['hasBulkMeter']);
    final hasBlockMeters = _toNullableBool(formData['hasBlockMeters']);

    final meteringProvided = _computeMeteringProvided(
      isHeatNetwork: isHeatNetwork,
      suppliesDwellings: suppliesDwellings,
      numBlocks: numBlocks,
      totalMeterCount: totalMeterCount,
      bulkMeterCount: bulkMeterCount,
      blockMeterCount: blockMeterCount,
      allGeneratorsHaveIndividualMeters: allGeneratorsHaveIndividualMeters,
      allInspectedDwellingsMetered: allInspectedDwellingsMetered,
      anyInspectedDwellingMetered: anyInspectedDwellingMetered,
      anyGeneratorHasIndividualMeter: anyGeneratorHasIndividualMeter,
      hasBulkMeter: hasBulkMeter,
      hasBlockMeters: hasBlockMeters,
    );

    final billingImplicationFlag = _computeBillingImplicationFlag(
      isHeatNetwork: isHeatNetwork,
      meteringProvided: meteringProvided,
    );

    final networkCategory = isHeatNetwork
        ? _computeNetworkCategory(formData)
        : null;

    return {
      'schemaVersion': schemaVersion,
      'methodologyVersion': methodologyVersion,
      'computedAt': DateTime.now().toIso8601String(),
      'billingImplicationFlag': billingImplicationFlag,
      'isHeatNetwork': isHeatNetwork,
      'observationCount': observationCount,
      'unsafeCount': unsafeCount,
      'meteringProvided': meteringProvided,
      'networkClassification': networkClassification,
      'dwellingMeteringFeasibility': dwellingMeteringFeasibility,
      'networkCategory': networkCategory,
      'numberOfDwellingsInspected': numberOfDwellingsInspected,
      'plantInPoorCondition': plantInPoorCondition,
      'assistedLivingIndicators': assistedLivingIndicators,
      'buildingUseCases': buildingUseCases,
    };
  }

  static bool _equalsYes(dynamic value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'yes' || text == 'true' || text == 'y';
  }

  static bool _isBulkMeterType(String meterType) =>
      meterType.toLowerCase().contains('bulk') ||
      meterType.toLowerCase().contains('inlet');

  static bool _isBlockMeterType(String meterType) =>
      meterType.toLowerCase().contains('block');

  static List<String> _toStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.where((e) => e != null).map((e) => e.toString()).toList();
  }

  static int _countAssistedLivingIndicators(Map<String, dynamic> formData) {
    final selected = _toStringList(formData['supportedFacilities']);
    final other = (formData['supportedFacilitiesOther'] ?? '')
        .toString()
        .trim();
    return selected.length + (other.isEmpty ? 0 : 1);
  }

  static String _buildBuildingUseCases(Map<String, dynamic> formData) {
    final nature = _toStringList(formData['buildingNature']);
    final other = (formData['buildingNatureOther'] ?? '').toString().trim();
    final values = <String>[];
    for (final n in nature) {
      if (n.trim().isEmpty) continue;
      if (n.trim().toLowerCase() == 'other') continue;
      values.add(n.trim());
    }
    if (other.isNotEmpty) values.add(other);
    return values.join(', ');
  }

  static int? _computeNetworkCategory(Map<String, dynamic> formData) {
    final raw = (formData['approximateNetworkAge'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final v = raw.toLowerCase();
    if (v.contains('under 5') || v.contains('up to 5') || v.contains('0-5')) {
      return 1;
    }
    if (v.contains('5-20') ||
        v.contains('5 - 20') ||
        v.contains('10 - 20') ||
        v.contains('10-20')) {
      return 2;
    }
    if (v.contains('20+') || v.contains('20 +')) {
      return 3;
    }
    return null;
  }

  static String _computeMeteringProvided({
    required bool isHeatNetwork,
    required bool suppliesDwellings,
    required int numBlocks,
    required int totalMeterCount,
    required int bulkMeterCount,
    required int blockMeterCount,
    required bool allGeneratorsHaveIndividualMeters,
    required bool allInspectedDwellingsMetered,
    required bool anyInspectedDwellingMetered,
    required bool anyGeneratorHasIndividualMeter,
    required bool? hasBulkMeter,
    required bool? hasBlockMeters,
  }) {
    if (!isHeatNetwork) return 'not_applicable';

    final blocks = numBlocks <= 0 ? 1 : numBlocks;

    // Evidence signals (visual inspection + info provided in the form).
    final bulkEvidence = (hasBulkMeter == true) || bulkMeterCount > 0;
    final blockEvidence = (hasBlockMeters == true) || blockMeterCount > 0;
    final dwellingEvidence = suppliesDwellings && anyInspectedDwellingMetered;
    final generatorEvidence = anyGeneratorHasIndividualMeter;

    final anyEvidence =
        totalMeterCount > 0 ||
        bulkEvidence ||
        blockEvidence ||
        dwellingEvidence ||
        generatorEvidence;

    final blockRequired = blocks > 1;
    final blockOk =
        !blockRequired || blockMeterCount >= blocks || hasBlockMeters == true;

    // Generator metering is expected for communal networks in this project.
    // If we have plant assets recorded, we require individual metering evidence on each.
    final generatorOk = allGeneratorsHaveIndividualMeters;

    final dwellingOk = suppliesDwellings ? allInspectedDwellingsMetered : true;

    final fullyMetered = bulkEvidence && generatorOk && blockOk && dwellingOk;

    if (fullyMetered) return 'present';
    if (!anyEvidence) return 'not_present';
    return 'partial';
  }

  static String _computeDwellingMeteringFeasibilityFromInspectionsJson({
    required bool isHeatNetwork,
    required bool suppliesDwellings,
    required String meteringProvided,
    required List<Map<String, dynamic>> dwellingInspections,
  }) {
    if (!isHeatNetwork) return 'N/A';
    if (!suppliesDwellings) return 'N/A';
    if (meteringProvided.toLowerCase() == 'present') return 'N/A';
    if (dwellingInspections.isEmpty) return 'Further investigation required';

    var anyFurther = false;
    var anyYes = false;
    var anyNo = false;

    void absorb(dynamic value) {
      final v = (value ?? '').toString().trim().toLowerCase();
      if (v.isEmpty) return;
      if (v == 'yes') anyYes = true;
      if (v == 'no') anyNo = true;
      if (v.contains('further') || v.contains('investigation')) {
        anyFurther = true;
      }
    }

    for (final d in dwellingInspections) {
      absorb(d['heatingSubMeterFeasible']);
      absorb(d['dhwSubMeterFeasible']);
    }

    if (anyFurther) return 'Further investigation required';
    if (anyYes) return 'Potentially feasible';
    if (anyNo) return 'Likely not feasible';
    return 'Further investigation required';
  }

  static int _countPlantItemsInPoorConditionJson({
    required List<Map<String, dynamic>> generators,
    required List<Map<String, dynamic>> phex,
    required List<Map<String, dynamic>> dhwPlants,
    required List<Map<String, dynamic>> communalControls,
  }) {
    bool isPoor(String? condition) {
      final v = (condition ?? '').toLowerCase();
      return v.contains('poor') || v.contains('replace');
    }

    var count = 0;
    for (final g in generators) {
      if (isPoor((g['condition'] ?? '').toString())) count++;
    }
    for (final p in phex) {
      if (isPoor((p['condition'] ?? '').toString())) count++;
    }
    for (final d in dhwPlants) {
      if (isPoor((d['condition'] ?? '').toString())) count++;
    }
    for (final c in communalControls) {
      if (isPoor((c['condition'] ?? '').toString())) count++;
    }
    return count;
  }

  static String _normalizeNetworkType(dynamic raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case 'District Heat Network':
        return 'district';
      case 'Communal Heat Network':
        return 'communal';
      case 'In-Flat Generation':
        return 'in_flat';
      case 'Communal areas only':
        return 'communal_areas_only';
      case 'Shared accommodation (no separate premises)':
        return 'shared_accommodation_no_separate_premises';
      default:
        return value == null || value.isEmpty ? 'unknown' : 'unknown';
    }
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

  static String _computeBillingImplicationFlag({
    required bool isHeatNetwork,
    required String meteringProvided,
  }) {
    if (!isHeatNetwork) return 'not_applicable';

    return meteringProvided.toLowerCase() == 'present'
        ? 'metering_present'
        : 'metering_not_confirmed';
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  static List<Map<String, dynamic>> _asListOfMapsFromDynamicList(
    List<dynamic>? value,
  ) {
    if (value == null) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }
}
