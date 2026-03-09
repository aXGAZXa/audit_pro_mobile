import 'dart:convert';

/// Builds an app-prepared PDF model that matches the portal-side
/// `HeatNetworkAssessmentModel` (C#) used by the HNA PDF template.
///
/// The portal can hydrate attachment IDs (e.g. `att_0001`) into base64
/// and render the PDF without doing heavy payload mapping.
class HnaPdfModelBuilder {
  static Map<String, dynamic> build({
    required int formId,
    required String reportNumber,
    required Map<String, dynamic> formData,
    required Map<String, dynamic> assetsJson,
    required List<Map<String, dynamic>> observationsJson,
    required List<Map<String, dynamic>> unsafeObservationsJson,
    required List<Map<String, dynamic>> unsafeReportsJson,
    required List<Map<String, dynamic>> attachments,
  }) {
    final attachmentIdByLocalPath = _buildAttachmentIdByLocalPath(attachments);

    String idOrEmpty(String? localPath) {
      if (localPath == null) return '';
      final trimmed = localPath.trim();
      if (trimmed.isEmpty) return '';
      return attachmentIdByLocalPath[trimmed] ?? '';
    }

    List<String> idList(dynamic maybeList) {
      if (maybeList is! List) return const <String>[];
      final result = <String>[];
      for (final item in maybeList) {
        if (item == null) continue;
        final id = idOrEmpty(item.toString());
        if (id.isNotEmpty) result.add(id);
      }
      return result;
    }

    final auditDateRaw = _getString(formData, 'auditDate');
    final networkTypeRaw = _getString(formData, 'meetsHeatNetworkDefinition');

    final isDistrictNetwork = _equalsIgnoreCase(
      networkTypeRaw,
      'District Heat Network',
    );
    final isCommunalNetwork = _equalsIgnoreCase(
      networkTypeRaw,
      'Communal Heat Network',
    );

    final buildingNature = _getStringList(formData, 'buildingNature');
    final isResidential = buildingNature.any(
      (b) => _equalsIgnoreCase(b, 'Residential'),
    );

    final model = <String, dynamic>{
      'ReportNumber': reportNumber,
      'ClientName': _getString(formData, 'client'),
      'UPRPNEnabled': _getBool(formData, 'uprpnEnabled'),
      'UPRPN': _getString(formData, 'uprpn'),
      'InspectionDate': _formatDate(auditDateRaw),
      'EstimatedBuildingAge': _getString(formData, 'approximateBuildingAge'),
      'SiteName': _getString(formData, 'siteName'),
      'StreetAddress': _getString(formData, 'streetAddress'),
      'TownCity': _getString(formData, 'townCity'),
      'Postcode': _getString(formData, 'postcode'),
      'AssessorName': _getString(formData, 'auditorName'),
      // Portal will hydrate attachment IDs -> base64.
      'AssessorSignatureBase64': idOrEmpty(
        _getStringOrNull(formData, 'auditorSignature'),
      ),
      'SignatureDate': _formatDate(auditDateRaw),
      'SiteRepName': _getString(formData, 'siteRepName'),
      'SiteRepSignatureBase64': idOrEmpty(
        _getStringOrNull(formData, 'siteRepSignature'),
      ),
      'HasSiteRepSignature': false, // set below

      'MeetsHeatNetworkDefinitionRaw': networkTypeRaw,
      'NetworkDefinitionLabel': _buildNetworkDefinitionLabel(networkTypeRaw),
      'EstimatedNetworkAge': _getString(formData, 'approximateNetworkAge'),
      'IsDistrictNetwork': isDistrictNetwork,
      'IsCommunalNetwork': isCommunalNetwork,
      'IsHeatNetwork': isDistrictNetwork || isCommunalNetwork,
      'ShowGenerators': !_equalsIgnoreCase(
        networkTypeRaw,
        'In-Flat Generation',
      ),

      'BuildingNature': buildingNature,
      'BuildingNatureOther': _getString(formData, 'buildingNatureOther'),
      'DwellingTypes': _getStringList(formData, 'dwellingTypes'),

      'NumBlocks': _getIntAsString(formData, 'numBlocks'),
      'MaxFloors': _getIntAsString(formData, 'maxFloors'),
      'NumDwellings': _getIntAsString(formData, 'numDwellings'),

      'IsResidential': isResidential,
      'ShowSupportedFacilities': isResidential,
      'SupportedFacilities': _getStringList(formData, 'supportedFacilities'),
      'SupportedFacilitiesOther': _getString(
        formData,
        'supportedFacilitiesOther',
      ),

      'HasBulkMeter': _equalsIgnoreCase(
        _getString(formData, 'hasBulkMeter'),
        'Yes',
      ),
      'HasBlockMeters': _equalsIgnoreCase(
        _getString(formData, 'hasBlockMeters'),
        'Yes',
      ),

      // Template section visibility (computed after assets are populated)
      'HideMeteringSection': false,
      'HideDwellingInspectionsSection': false,

      // System overview (template uses Question + Reason + DHW plant answer)
      'CommunalPipeworkQuestion': 'Communal pipework insulation',
      'CommunalPipeworkReason': _buildPipeworkReason(formData),
      'DedicatedCommunalDhwPlantQuestion': 'Dedicated communal DHW plant',
      'DedicatedCommunalDhwPlant': _getString(
        formData,
        'dedicatedCommunalDhwPlant',
      ),
      'DedicatedCommunalDhwPlantUnknownReason': _getString(
        formData,
        'dedicatedCommunalDhwPlantUnknownReason',
      ),

      // Dwelling inspections (template uses these)
      'DwellingInspectionAccessQuestion': 'Were dwelling inspections possible?',
      'AreDwellingInspectionsPossible': _equalsIgnoreCase(
        _getString(formData, 'dwellingInspectionsPossible'),
        'Yes',
      ),
      'DwellingConsistencyQuestion': 'Are dwelling arrangements consistent?',
      'DwellingArrangementsConsistent':
          (_getStringOrNull(formData, 'dwellingArrangementsConsistent') ??
          'Unverified'),
      'AreDwellingArrangementsConsistent': _equalsIgnoreCase(
        _getStringOrNull(formData, 'dwellingArrangementsConsistent') ?? '',
        'Yes',
      ),
      'HeatSuppliedUnclearDetails': _getString(
        formData,
        'heatSuppliedUnclearDetails',
      ),

      // Assets
      'BulkMeters': <Map<String, dynamic>>[],
      'BlockMeters': <Map<String, dynamic>>[],
      'HeatGenerators': <Map<String, dynamic>>[],
      'Phexes': <Map<String, dynamic>>[],
      'DhwPlants': <Map<String, dynamic>>[],
      'CommunalControls': <Map<String, dynamic>>[],
      'DwellingInspections': <Map<String, dynamic>>[],

      // Derived (metering narrative + triage)
      'MeteringMessages': <String>[],
      'TriageNetworkClassificationSummary': '',
      'TriageNetworkCategory': '',
      'TriageNetworkCategoryMeaning': '',
      'TriageMeteringRiskSignals': <String>[],
      'TriageDwellingConsistencySignals': <String>[],
      'TriageRegulatoryPreparednessSignals': <String>[],
      'TriageStrategicFramingFlags': <String>[],
      'TriageConfidenceAndLimitations': '',
      'TriageVisualCaveatStatement': '',

      // Unsafe
      'UnsafeSituations': <Map<String, dynamic>>[],
      'UnsafeReports': <Map<String, dynamic>>[],
    };

    model['HasSiteRepSignature'] =
        (_getString(model, 'SiteRepName').trim().isNotEmpty) ||
        (_getString(model, 'SiteRepSignatureBase64').trim().isNotEmpty);

    _populateAssets(
      model: model,
      assetsJson: assetsJson,
      imageIdListFromLocalPathList: idList,
    );

    final bulkMeters = (model['BulkMeters'] as List?) ?? const [];
    final blockMeters = (model['BlockMeters'] as List?) ?? const [];
    final hasRecordedMeters = bulkMeters.isNotEmpty || blockMeters.isNotEmpty;
    final isHeatNetwork = model['IsHeatNetwork'] == true;
    model['HideMeteringSection'] = !isHeatNetwork && !hasRecordedMeters;

    final numDwellings =
        int.tryParse(_getIntAsString(formData, 'numDwellings')) ?? 0;
    model['HideDwellingInspectionsSection'] = numDwellings <= 0;

    _populateObservations(
      model: model,
      observationsJson: observationsJson,
      imageIdListFromLocalPathList: idList,
      unsafeObservationIds: unsafeObservationsJson
          .map((o) => (o['id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
      unsafeReportsJson: unsafeReportsJson,
    );

    _populatePdfDerived(model: model, formData: formData);

    _populateSystemOverview(model: model, formData: formData);

    _populateUnsafeReports(
      model: model,
      unsafeObservationsJson: unsafeObservationsJson,
      unsafeReportsJson: unsafeReportsJson,
      imageIdFromLocalPath: idOrEmpty,
    );

    return model;
  }

  static void _populateObservations({
    required Map<String, dynamic> model,
    required List<Map<String, dynamic>> observationsJson,
    required List<String> Function(dynamic) imageIdListFromLocalPathList,
    required Set<String> unsafeObservationIds,
    required List<Map<String, dynamic>> unsafeReportsJson,
  }) {
    // Index meter maps by reference so we can attach meter-specific observations.
    final meterRefById = <String, Map>{};

    void indexRefs(dynamic list) {
      if (list is! List) return;
      for (final item in list) {
        if (item is! Map) continue;
        final id = (item['Id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          meterRefById[id] = item;
        }
      }
    }

    indexRefs(model['BulkMeters']);
    indexRefs(model['BlockMeters']);

    // Index dwelling inspections so we can attach observations under the correct dwelling.
    final dwellingById = <String, Map>{};
    final dwellings = model['DwellingInspections'];
    if (dwellings is List) {
      for (final item in dwellings) {
        if (item is! Map) continue;
        final id = (item['Id'] ?? '').toString().trim();
        if (id.isNotEmpty) dwellingById[id] = item;
      }
    }

    // Best-effort map: unsafe observation id -> action taken (from unsafe reports).
    final actionByUnsafeObsId = <String, String>{};
    for (final r in unsafeReportsJson) {
      final action = (r['actionTaken'] ?? '').toString().trim();
      if (action.isEmpty) continue;
      final ids = _parseObservationIds(r['observationIds']);
      for (final id in ids) {
        if (id.trim().isEmpty) continue;
        actionByUnsafeObsId[id] = action;
      }
    }

    final communalSpaceHeating = <Map<String, dynamic>>[];
    final communalPipework = <Map<String, dynamic>>[];

    for (final o in observationsJson) {
      final obsId = (o['id'] ?? '').toString().trim();
      final isUnsafe = unsafeObservationIds.contains(obsId);

      final ref = (o['questionReference'] ?? o['question_reference'] ?? '')
          .toString()
          .trim();
      if (ref.isEmpty) continue;

      final questionText = (o['questionText'] ?? o['question_text'] ?? '')
          .toString();
      final notes = (o['notes'] ?? '').toString();
      final unsafeClass =
          (o['unsafe_classification'] ??
                  o['unsafeClassification'] ??
                  o['unsafeClassificationCode'] ??
                  '')
              .toString()
              .trim();

      String formattedNotes = notes;
      String? unsafeActionTaken;
      if (isUnsafe) {
        final prefix = unsafeClass.isNotEmpty
            ? 'UNSAFE ($unsafeClass): '
            : 'UNSAFE: ';
        formattedNotes = '$prefix$formattedNotes'.trim();

        unsafeActionTaken = actionByUnsafeObsId[obsId];
        if (unsafeActionTaken != null && unsafeActionTaken.trim().isNotEmpty) {
          formattedNotes =
              '$formattedNotes (Actions taken: ${unsafeActionTaken.trim()})';
        }
      }
      final images = imageIdListFromLocalPathList(
        o['imagePaths'] ?? o['images'],
      );

      final obsModel = <String, dynamic>{
        'QuestionText': questionText,
        'Notes': formattedNotes,
        'Images': images,
        'IsUnsafe': isUnsafe,
        if (isUnsafe && unsafeClass.isNotEmpty)
          'UnsafeClassification': unsafeClass,
        if (isUnsafe &&
            unsafeActionTaken != null &&
            unsafeActionTaken.trim().isNotEmpty)
          'UnsafeActionTaken': unsafeActionTaken.trim(),
      };

      // Meter observations: attach under the corresponding meter.
      if (ref.startsWith('heat_meter_')) {
        final fromAssetId = (o['assetId'] ?? o['asset_id'] ?? '')
            .toString()
            .trim();
        final fromRef = ref.substring('heat_meter_'.length).trim();
        final meterId = fromAssetId.isNotEmpty ? fromAssetId : fromRef;
        final meter = meterRefById[meterId];
        if (meter != null) {
          final list = meter.putIfAbsent(
            'Observations',
            () => <Map<String, dynamic>>[],
          );
          if (list is List) {
            list.add(obsModel);
          }
          continue;
        }
      }

      // Key communal observation buckets used in the template.
      if (ref == 'communal_space_heating') {
        communalSpaceHeating.add(obsModel);
      } else if (ref == 'communal_pipework') {
        communalPipework.add(obsModel);
      } else if (ref.startsWith('dwelling_')) {
        final dwellingId = ref.substring('dwelling_'.length).trim();
        final dwelling = dwellingById[dwellingId];
        if (dwelling != null) {
          final list = dwelling.putIfAbsent(
            'Observations',
            () => <Map<String, dynamic>>[],
          );
          if (list is List) {
            list.add(obsModel);
          }
        }
      }
    }

    if (communalSpaceHeating.isNotEmpty) {
      model['CommunalSpaceHeatingObservations'] = communalSpaceHeating;
    }
    if (communalPipework.isNotEmpty) {
      model['CommunalPipeworkObservations'] = communalPipework;
    }
  }

  static Map<String, String> _buildAttachmentIdByLocalPath(
    List<Map<String, dynamic>> attachments,
  ) {
    final map = <String, String>{};
    for (final a in attachments) {
      final localPath = a['localPath']?.toString().trim();
      final id = a['id']?.toString().trim();
      if (localPath == null || localPath.isEmpty) continue;
      if (id == null || id.isEmpty) continue;
      map[localPath] = id;
    }
    return map;
  }

  static void _populateAssets({
    required Map<String, dynamic> model,
    required Map<String, dynamic> assetsJson,
    required List<String> Function(dynamic) imageIdListFromLocalPathList,
  }) {
    final meters = (assetsJson['heatMeters'] as List?) ?? const [];
    for (final m in meters) {
      if (m is! Map) continue;
      final meterType = (m['meterType'] ?? '').toString();
      final operational = (m['operational'] ?? '').toString();

      final meterModel = <String, dynamic>{
        'Id': (m['id'] ?? '').toString(),
        'NetworkType': meterType,
        'MeterType': meterType,
        'Location': (m['location'] ?? '').toString(),
        'Make': (m['make'] ?? '').toString(),
        'Model': (m['model'] ?? '').toString(),
        'SerialNumber': (m['serialNumber'] ?? '').toString(),
        'Reading': (m['reading'] ?? '').toString(),
        'Units': '',
        'AgeRange': (m['ageRange'] ?? '').toString(),
        'Condition': _equalsIgnoreCase(operational, 'YES')
            ? 'Operational'
            : 'Not operational',
        'Images': imageIdListFromLocalPathList(m['imagePaths']),
      };

      if (meterType.toLowerCase().contains('bulk')) {
        (model['BulkMeters'] as List).add(meterModel);
      } else if (meterType.toLowerCase().contains('block')) {
        (model['BlockMeters'] as List).add(meterModel);
      } else {
        (model['BulkMeters'] as List).add(meterModel);
      }
    }

    final generators = (assetsJson['heatGenerators'] as List?) ?? const [];
    for (final g in generators) {
      if (g is! Map) continue;
      (model['HeatGenerators'] as List).add({
        'Id': (g['id'] ?? '').toString(),
        'Location': (g['location'] ?? '').toString(),
        'Make': (g['make'] ?? '').toString(),
        'Model': (g['model'] ?? '').toString(),
        'SerialNumber': (g['serialNumber'] ?? '').toString(),
        'Type': (g['generatorType'] ?? '').toString(),
        'OutputRating': (g['capacity'] ?? '').toString(),
        'AgeRange': (g['ageRange'] ?? '').toString(),
        'Condition': (g['condition'] ?? '').toString(),
        'Operational': _mapOperationalState(g['operational']),
        'FuelType': (g['fuelType'] ?? '').toString(),
        'Images': imageIdListFromLocalPathList(g['imagePaths']),
      });
    }

    final phexes = (assetsJson['plateHeatExchangers'] as List?) ?? const [];
    for (final p in phexes) {
      if (p is! Map) continue;
      (model['Phexes'] as List).add({
        'Id': (p['id'] ?? '').toString(),
        'Location': (p['location'] ?? '').toString(),
        'Make': (p['make'] ?? '').toString(),
        'Model': (p['model'] ?? '').toString(),
        'SerialNumber': (p['serialNumber'] ?? '').toString(),
        'Capacity': (p['capacity'] ?? '').toString(),
        'AgeRange': (p['ageRange'] ?? '').toString(),
        'Condition': (p['condition'] ?? '').toString(),
        'Operational': _mapOperationalState(p['operational']),
        'InsulationCondition': (p['insulationCondition'] ?? '').toString(),
        'FreeOfLeaks': (p['freeOfLeaks'] ?? '').toString(),
        'HasIsolationValves': (p['hasIsolationValves'] ?? '').toString(),
        'HasTempGauges': (p['hasTempGauges'] ?? '').toString(),
        'HasIndividualMeter': (p['hasIndividualMeter'] ?? '').toString(),
        'Images': imageIdListFromLocalPathList(p['imagePaths']),
      });
    }

    final dhwPlants = (assetsJson['dhwPlants'] as List?) ?? const [];
    for (final d in dhwPlants) {
      if (d is! Map) continue;
      (model['DhwPlants'] as List).add({
        'Id': (d['id'] ?? '').toString(),
        'Type': (d['plantType'] ?? '').toString(),
        'Location': (d['location'] ?? '').toString(),
        'Make': (d['make'] ?? '').toString(),
        'Model': (d['model'] ?? '').toString(),
        'Capacity': (d['capacity'] ?? '').toString(),
        'AgeRange': (d['ageRange'] ?? '').toString(),
        'Condition': (d['condition'] ?? '').toString(),
        'Operational': _mapOperationalState(d['operational']),
        'InsulationCondition': '',
        'Images': imageIdListFromLocalPathList(d['imagePaths']),
      });
    }

    final controls = (assetsJson['communalControls'] as List?) ?? const [];
    for (final c in controls) {
      if (c is! Map) continue;
      (model['CommunalControls'] as List).add({
        'Id': (c['id'] ?? '').toString(),
        'Type': (c['controlType'] ?? '').toString(),
        'Location': (c['location'] ?? '').toString(),
        'Make': (c['make'] ?? '').toString(),
        'Model': (c['model'] ?? '').toString(),
        'SerialNumber': (c['serialNumber'] ?? '').toString(),
        'AgeRange': (c['ageRange'] ?? '').toString(),
        'Description': '',
        'Condition': (c['condition'] ?? '').toString(),
        'Operational': _mapOperationalState(c['operational']),
        'Images': imageIdListFromLocalPathList(c['imagePaths']),
      });
    }

    final dwellingInspections =
        (assetsJson['dwellingInspections'] as List?) ?? const [];
    for (final di in dwellingInspections) {
      if (di is! Map) continue;
      (model['DwellingInspections'] as List).add({
        'Id': (di['id'] ?? '').toString(),
        'Location': (di['location'] ?? '').toString(),
        'HeatingType': (di['heatingType'] ?? '').toString(),
        'HeatGeneratorType': (di['heatGeneratorType'] ?? '').toString(),
        'HeatGeneratorFuelType': (di['heatGeneratorFuelType'] ?? '').toString(),
        'HeatDistributionType': (di['heatDistributionType'] ?? '').toString(),
        'DhwType': (di['dhwType'] ?? '').toString(),
        'DhwGeneratorType': (di['dhwGeneratorType'] ?? '').toString(),
        'DhwGeneratorFuelType': (di['dhwGeneratorFuelType'] ?? '').toString(),
        'DhwCommunalType': (di['dhwCommunalType'] ?? '').toString(),
        'HeatingControls': _toStringList(di['heatingControls']),
        'HeatingControlsOther': (di['heatingControlsOther'] ?? '').toString(),
        'HeatingNotes': (di['heatingNotes'] ?? '').toString(),
        'HeatingImages': imageIdListFromLocalPathList(di['heatingImagePaths']),
        'DhwControls': _toStringList(di['dhwControls']),
        'DhwControlsOther': (di['dhwControlsOther'] ?? '').toString(),
        'DhwNotes': (di['dhwNotes'] ?? '').toString(),
        'DhwImages': imageIdListFromLocalPathList(di['dhwImagePaths']),
        'Condition': (di['condition'] ?? '').toString(),
        'Operational': (di['operational'] ?? '').toString(),
        'HIUMake': (di['hiuMake'] ?? '').toString(),
        'HIUModel': (di['hiuModel'] ?? '').toString(),
        'HIUSerial': (di['hiuSerialNumber'] ?? '').toString(),
        'HeatingMetered': (di['heatingMetered'] ?? '').toString(),
        'DhwMetered': (di['dhwMetered'] ?? '').toString(),
        'HeatingSubMeterFeasible': (di['heatingSubMeterFeasible'] ?? '')
            .toString(),
        'HeatingSubMeterFeasibilityReason':
            (di['heatingSubMeterFeasibilityReason'] ?? '').toString(),
        'HeatingSubMeterEvidenceImages': imageIdListFromLocalPathList(
          di['heatingSubMeterEvidenceImages'],
        ),
        'DhwSubMeterFeasible': (di['dhwSubMeterFeasible'] ?? '').toString(),
        'DhwSubMeterFeasibilityReason':
            (di['dhwSubMeterFeasibilityReason'] ?? '').toString(),
        'DhwSubMeterEvidenceImages': imageIdListFromLocalPathList(
          di['dhwSubMeterEvidenceImages'],
        ),
        'Images': imageIdListFromLocalPathList(di['imagePaths']),
      });
    }
  }

  static String _mapOperationalState(dynamic raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    if (normalized.isEmpty) return '';
    if (normalized == 'yes' ||
        normalized == 'operational' ||
        normalized == 'true') {
      return 'Operational';
    }
    if (normalized == 'no' ||
        normalized == 'not operational' ||
        normalized == 'false') {
      return 'Not operational';
    }
    return (raw ?? '').toString().trim();
  }

  static void _populatePdfDerived({
    required Map<String, dynamic> model,
    required Map<String, dynamic> formData,
  }) {
    final pdfDerivedRaw = formData['pdfDerived'];
    if (pdfDerivedRaw is! Map) return;

    model['MeteringMessages'] = _toStringList(
      pdfDerivedRaw['meteringMessages'],
    );

    model['TriageNetworkClassificationSummary'] =
        (pdfDerivedRaw['triageNetworkClassificationSummary'] ?? '').toString();
    model['TriageNetworkCategory'] =
        (pdfDerivedRaw['triageNetworkCategory'] ?? '').toString();
    model['TriageNetworkCategoryMeaning'] =
        (pdfDerivedRaw['triageNetworkCategoryMeaning'] ?? '').toString();

    model['TriageMeteringRiskSignals'] = _toStringList(
      pdfDerivedRaw['triageMeteringRiskSignals'],
    );
    model['TriageDwellingConsistencySignals'] = _toStringList(
      pdfDerivedRaw['triageDwellingConsistencySignals'],
    );
    model['TriageRegulatoryPreparednessSignals'] = _toStringList(
      pdfDerivedRaw['triageRegulatoryPreparednessSignals'],
    );
    model['TriageStrategicFramingFlags'] = _toStringList(
      pdfDerivedRaw['triageStrategicFramingFlags'],
    );

    model['TriageConfidenceAndLimitations'] =
        (pdfDerivedRaw['triageConfidenceAndLimitations'] ?? '').toString();
    model['TriageVisualCaveatStatement'] =
        (pdfDerivedRaw['triageVisualCaveatStatement'] ?? '').toString();
  }

  static void _populateSystemOverview({
    required Map<String, dynamic> model,
    required Map<String, dynamic> formData,
  }) {
    String? normalizeRadiatorCondition(String? value) {
      if (value == null) return null;
      final v = value.trim();
      if (v.isEmpty) return null;

      if (_equalsIgnoreCase(v, 'Fitted with TRVs')) return 'fitted with TRVs';
      if (_equalsIgnoreCase(v, 'Not fitted with TRVs')) {
        return 'not fitted with TRVs';
      }
      if (_equalsIgnoreCase(v, 'Some fitted with TRVs') ||
          _equalsIgnoreCase(v, 'Some fitted')) {
        return 'some fitted with TRVs';
      }

      if (v.length == 1) return v.toLowerCase();
      return v[0].toLowerCase() + v.substring(1);
    }

    String formatHumanList(List<String> items) {
      if (items.isEmpty) return '';
      if (items.length == 1) return items[0];
      if (items.length == 2) return '${items[0]} and ${items[1]}';
      return '${items.sublist(0, items.length - 1).join(', ')}, and ${items.last}';
    }

    // Heat (communal space heating)
    final communalSpaceHeating = _getStringList(
      formData,
      'communalSpaceHeating',
    );
    if (communalSpaceHeating.isNotEmpty) {
      final communalSpaceHeatingOther = _getStringOrNull(
        formData,
        'communalSpaceHeatingOther',
      );
      final communalRadiatorCondition = _getStringOrNull(
        formData,
        'communalRadiatorCondition',
      );

      final displayItems = <String>[];
      for (final raw in communalSpaceHeating) {
        var s = raw;
        if (_equalsIgnoreCase(s, 'Other') &&
            communalSpaceHeatingOther != null &&
            communalSpaceHeatingOther.trim().isNotEmpty) {
          s = 'Other (${communalSpaceHeatingOther.trim()})';
        }

        if (_equalsIgnoreCase(s, 'Radiators')) {
          final normalized = normalizeRadiatorCondition(
            communalRadiatorCondition,
          );
          s = (normalized == null || normalized.trim().isEmpty)
              ? 'Radiators'
              : 'Radiators (${normalized.trim()})';
        }

        if (s.trim().isNotEmpty) displayItems.add(s.trim());
      }

      model['CommunalSpaceHeatingSummary'] = displayItems.isEmpty
          ? ''
          : 'Communal space heating is delivered via ${formatHumanList(displayItems)}.';

      // Match the old engine behavior: notes are blank (radiator condition is inlined).
      model['CommunalSpaceHeatingNotes'] = '';
    }

    // Communal pipework insulation statement (match old engine wording)
    final insulation =
        (_getStringOrNull(formData, 'communalPipeworkInsulation') ?? '').trim();
    final partCondition = _getStringOrNull(
      formData,
      'communalPipeworkPartInsulatedCondition',
    );
    final reason = _getStringOrNull(formData, 'communalPipeworkReason');
    model['CommunalPipeworkInsulationStatement'] = _buildPipeworkStatement(
      insulation,
      partCondition,
      reason,
    );

    // DHW (dedicated communal DHW plant) - match old engine wording
    final dedicated =
        (_getStringOrNull(formData, 'dedicatedCommunalDhwPlant') ?? '').trim();
    final dhwSecondaryReturn = _equalsIgnoreCase(dedicated, 'Yes')
        ? ((_getStringOrNull(formData, 'dhwSecondaryReturn') ?? '').trim())
        : '';
    final dhwSecondaryReturnSummary =
        _equalsIgnoreCase(dhwSecondaryReturn, 'Yes')
        ? 'It is fitted with a secondary return.'
        : '';

    if (dedicated.isNotEmpty) {
      String summary;
      if (_equalsIgnoreCase(dedicated, 'Yes')) {
        summary = dhwSecondaryReturnSummary.isNotEmpty
            ? 'A communal DHW system is installed at this site, and it is fitted with a secondary return.'
            : 'A communal DHW system is installed at this site.';
      } else if (_equalsIgnoreCase(dedicated, 'No')) {
        summary = 'No communal DHW system was identified at this site.';
      } else if (_equalsIgnoreCase(dedicated, 'Unknown')) {
        summary =
            'Unable to confirm whether a communal DHW system is installed at this site.';
      } else {
        summary = 'Communal DHW system was recorded as: $dedicated.';
      }

      model['DedicatedCommunalDhwPlantSummary'] = summary;
    }
  }

  static String _buildPipeworkStatement(
    String insulation,
    String? partCondition,
    String? reason,
  ) {
    if (insulation.trim().isEmpty &&
        (partCondition == null || partCondition.trim().isEmpty) &&
        (reason == null || reason.trim().isEmpty)) {
      return '';
    }

    final ins = insulation.trim();
    String baseSentence;
    if (_equalsIgnoreCase(ins, 'Fully insulated')) {
      baseSentence = 'The inspected communal pipework appears fully insulated';
    } else if (_equalsIgnoreCase(ins, 'Part insulated')) {
      baseSentence =
          'The inspected communal pipework appears partially insulated';
    } else if (_equalsIgnoreCase(ins, 'Not insulated')) {
      baseSentence = 'The inspected communal pipework appears not insulated';
    } else if (_equalsIgnoreCase(ins, 'Unable to Determine')) {
      baseSentence =
          'The inspected communal pipework insulation could not be determined';
    } else {
      baseSentence = ins.isEmpty
          ? 'The inspected communal pipework insulation was recorded'
          : 'The inspected communal pipework insulation was recorded as $ins';
    }

    final details = <String>[];
    if (partCondition != null && partCondition.trim().isNotEmpty) {
      details.add(_trimTrailingPunctuation(partCondition));
    }
    if (reason != null && reason.trim().isNotEmpty) {
      details.add(_trimTrailingPunctuation(reason));
    }

    if (details.isEmpty) return '$baseSentence.';
    return '$baseSentence; ${details.join('; ')}.';
  }

  static String _trimTrailingPunctuation(String value) {
    return value.trim().replaceFirst(RegExp(r'[.\s]+$'), '');
  }

  static void _populateUnsafeReports({
    required Map<String, dynamic> model,
    required List<Map<String, dynamic>> unsafeObservationsJson,
    required List<Map<String, dynamic>> unsafeReportsJson,
    required String Function(String?) imageIdFromLocalPath,
  }) {
    final unsafeObsById = <String, Map<String, dynamic>>{};
    for (final o in unsafeObservationsJson) {
      final id = (o['id'] ?? '').toString().trim();
      if (id.isNotEmpty) unsafeObsById[id] = o;
    }

    String yesNoOrRaw(dynamic value) {
      if (value == null) return '';
      if (value is bool) return value ? 'Yes' : 'No';
      if (value is num) return value != 0 ? 'Yes' : 'No';
      return value.toString();
    }

    String observationLabel(String id) {
      final o = unsafeObsById[id];
      if (o == null) return id;

      final label = _firstNonEmpty([
        o['questionText']?.toString(),
        o['assetMakeModel']?.toString(),
        o['sectionName']?.toString(),
      ]);

      return label.trim().isEmpty ? id : label;
    }

    for (final r in unsafeReportsJson) {
      final createdAt = (r['createdAt'] ?? r['created_at'] ?? '').toString();
      final actionTaken = (r['actionTaken'] ?? '').toString().trim();

      final obsIds = _parseObservationIds(r['observationIds']);
      final labels = <String>[];
      for (final id in obsIds) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) continue;
        labels.add(observationLabel(trimmed));
      }

      final reportedToClient = yesNoOrRaw(
        r['reportedToClient'] ?? r['reported_to_client'],
      );
      final reportedInternally = yesNoOrRaw(
        r['reportedInternally'] ?? r['reported_internally'],
      );

      final warningNoticeId = imageIdFromLocalPath(
        r['warningNoticeImage']?.toString(),
      );
      final afterImageId = imageIdFromLocalPath(r['afterImage']?.toString());

      (model['UnsafeReports'] as List).add({
        'CreatedAt': createdAt,
        'ObservationLabels': labels,
        'ActionTaken': actionTaken,
        'ReportedToClient': reportedToClient.toString(),
        'ReportedInternally': reportedInternally.toString(),
        // Portal will hydrate attachment IDs -> base64.
        'WarningNoticeImageBase64': warningNoticeId,
        'AfterImageBase64': afterImageId,
      });
    }
  }

  static List<String> _parseObservationIds(dynamic value) {
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <String>[];

      // Try JSON (e.g. "[\"id1\",\"id2\"]" or "[1,2]")
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .where((e) => e != null)
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        // ignore
      }

      // Fallback: split on commas
      return trimmed
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }

  static String _buildPipeworkReason(Map<String, dynamic> formData) {
    final parts = <String>[];

    final insulation = _getStringOrNull(formData, 'communalPipeworkInsulation');
    if (insulation != null && insulation.trim().isNotEmpty) {
      parts.add(insulation.trim());
    }

    final partCondition = _getStringOrNull(
      formData,
      'communalPipeworkPartInsulatedCondition',
    );
    if (partCondition != null && partCondition.trim().isNotEmpty) {
      parts.add(partCondition.trim());
    }

    final reason = _getStringOrNull(formData, 'communalPipeworkReason');
    if (reason != null && reason.trim().isNotEmpty) {
      parts.add(reason.trim());
    }

    return parts.join('; ');
  }

  static String _buildNetworkDefinitionLabel(String raw) {
    if (_equalsIgnoreCase(raw, 'In-Flat Generation')) {
      return 'Not a heat network for in flat only';
    }
    if (_equalsIgnoreCase(raw, 'Communal areas only')) {
      return 'Not a heat network: Communal areas only';
    }
    if (_equalsIgnoreCase(raw, 'Shared accommodation (no separate premises)')) {
      return 'Not a heat network: Shared accommodation (no separate premises / no self-contained dwellings)';
    }
    return raw;
  }

  static String _formatDate(String raw) {
    if (raw.trim().isEmpty) return '';

    // Already in expected PDF format.
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(raw.trim())) {
      return raw.trim();
    }

    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      final v = (c ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static bool _equalsIgnoreCase(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  static String _getString(Map map, String key) {
    final v = map[key];
    return v == null ? '' : v.toString();
  }

  static String? _getStringOrNull(Map map, String key) {
    final v = map[key];
    if (v == null) return null;
    final s = v.toString();
    return s.trim().isEmpty ? null : s;
  }

  static bool _getBool(Map map, String key) {
    final v = map[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }
    return false;
  }

  static List<String> _getStringList(Map map, String key) {
    return _toStringList(map[key]);
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <String>[];
      return <String>[trimmed];
    }
    return const <String>[];
  }

  static String _getIntAsString(Map map, String key) {
    final v = map[key];
    if (v == null) return '0';
    if (v is int) return v.toString();
    if (v is num) return v.toInt().toString();
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      return (parsed ?? 0).toString();
    }
    return '0';
  }
}
