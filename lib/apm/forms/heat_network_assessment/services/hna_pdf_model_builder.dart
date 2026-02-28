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
    };

    model['HasSiteRepSignature'] =
        (_getString(model, 'SiteRepName').trim().isNotEmpty) ||
        (_getString(model, 'SiteRepSignatureBase64').trim().isNotEmpty);

    _populateAssets(
      model: model,
      assetsJson: assetsJson,
      imageIdListFromLocalPathList: idList,
    );

    _populatePdfDerived(model: model, formData: formData);

    _populateUnsafeSituations(
      model: model,
      unsafeObservationsJson: unsafeObservationsJson,
      unsafeReportsJson: unsafeReportsJson,
      imageIdFromLocalPath: idOrEmpty,
      imageIdListFromLocalPathList: idList,
    );

    return model;
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

  static void _populateUnsafeSituations({
    required Map<String, dynamic> model,
    required List<Map<String, dynamic>> unsafeObservationsJson,
    required List<Map<String, dynamic>> unsafeReportsJson,
    required String Function(String?) imageIdFromLocalPath,
    required List<String> Function(dynamic) imageIdListFromLocalPathList,
  }) {
    final actionByObsId = <int, String>{};
    final extraImagesByObsId = <int, List<String>>{};

    for (final r in unsafeReportsJson) {
      final action = (r['actionTaken'] ?? '').toString();
      final obsIds = _parseObservationIds(r['observationIds']);
      for (final id in obsIds) {
        if (action.trim().isNotEmpty) actionByObsId[id] = action;

        final warningId = imageIdFromLocalPath(
          r['warningNoticeImage']?.toString(),
        );
        final afterId = imageIdFromLocalPath(r['afterImage']?.toString());

        final list = extraImagesByObsId.putIfAbsent(id, () => <String>[]);
        if (warningId.isNotEmpty) list.add(warningId);
        if (afterId.isNotEmpty) list.add(afterId);
      }
    }

    for (final o in unsafeObservationsJson) {
      final obsId = _toInt(o['id']);

      final images = <String>[];
      images.addAll(imageIdListFromLocalPathList(o['imagePaths']));

      // These are present on observations; including them makes the PDF more complete.
      final noticeId = imageIdFromLocalPath(
        o['unsafeWarningNoticeImage']?.toString(),
      );
      if (noticeId.isNotEmpty) images.add(noticeId);
      final afterId = imageIdFromLocalPath(o['unsafeAfterImage']?.toString());
      if (afterId.isNotEmpty) images.add(afterId);

      if (obsId != null) {
        final extra = extraImagesByObsId[obsId];
        if (extra != null && extra.isNotEmpty) images.addAll(extra);
      }

      final location = _firstNonEmpty([
        o['assetMakeModel']?.toString(),
        o['questionText']?.toString(),
        o['sectionName']?.toString(),
        'Unsafe observation',
      ]);

      (model['UnsafeSituations'] as List).add({
        'Location': location,
        'Description': (o['notes'] ?? '').toString(),
        'RiskLevel': (o['unsafeClassification'] ?? '').toString(),
        'RemedialAction': obsId != null ? (actionByObsId[obsId] ?? '') : '',
        'Images': images,
      });
    }
  }

  static List<int> _parseObservationIds(dynamic value) {
    if (value is List) {
      return value
          .map((e) => _toInt(e))
          .whereType<int>()
          .toList(growable: false);
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <int>[];

      // Try JSON (e.g. "[1,2]")
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => _toInt(e))
              .whereType<int>()
              .toList(growable: false);
        }
      } catch (_) {
        // ignore
      }

      // Fallback: split on commas
      final parts = trimmed
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      final ids = <int>[];
      for (final p in parts) {
        final parsed = int.tryParse(p);
        if (parsed != null) ids.add(parsed);
      }
      return ids;
    }

    return const <int>[];
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

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return int.tryParse(value.toString());
  }
}
