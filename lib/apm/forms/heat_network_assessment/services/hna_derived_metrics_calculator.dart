import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/models/dwelling_inspection.dart';
import 'package:audit_pro_mobile/apm/models/heat_meter.dart';

class HnaDerivedMetricsCalculator {
  static const int schemaVersion = 1;

  static Map<String, dynamic> _computeCore({
    required Map<String, dynamic> formData,
    required Map<String, int> meterCountsByType,
    required int generatorCount,
    required Map<String, int> generatorTypeCounts,
    required Map<String, int> fuelTypeCounts,
    required int phexCount,
    required int dhwPlantCount,
    required int communalControlCount,
    required int dwellingInspectionCount,
    required Map<String, dynamic> subMeteringCounts,
    required int observationCount,
    required int unsafeObservationCount,
    required int unsafeReportCount,
    required int unsafeUnreportedCount,
    required String methodologyVersion,
  }) {
    final networkTypeRaw = formData['meetsHeatNetworkDefinition'];
    final networkType = _normalizeNetworkType(networkTypeRaw);

    final isHeatNetwork =
        networkType == 'district' || networkType == 'communal';
    final suppliesDwellings = networkType != 'communal_areas_only';

    final numBlocks = _toInt(formData['numBlocks']);
    final maxFloors = _toInt(formData['maxFloors']);
    final numDwellings = _toInt(formData['numDwellings']);

    final hasBulkMeter = _toNullableBool(formData['hasBulkMeter']);
    final hasBlockMeters = _toNullableBool(formData['hasBlockMeters']);

    final meteringLevel = _computeMeteringLevel(
      meterCountsByType: meterCountsByType,
      hasBulkMeter: hasBulkMeter,
      hasBlockMeters: hasBlockMeters,
    );

    final billingImplicationFlag = _computeBillingImplicationFlag(
      isHeatNetwork: isHeatNetwork,
      hasAnyMeters: meterCountsByType.isNotEmpty,
      hasBulkMeter: hasBulkMeter,
      hasBlockMeters: hasBlockMeters,
    );

    final dataQualityFlags = <String>[];
    if (hasBulkMeter == true && meterCountsByType.isEmpty) {
      dataQualityFlags.add('HAS_BULK_METER_YES_BUT_NO_METER_ASSETS');
    }
    if (hasBlockMeters == true && meterCountsByType.isEmpty) {
      dataQualityFlags.add('HAS_BLOCK_METERS_YES_BUT_NO_METER_ASSETS');
    }

    final hasBlockingUnsafeItems = unsafeUnreportedCount > 0;

    final reportingTags = _computeReportingTags(
      isHeatNetwork: isHeatNetwork,
      meteringLevel: meteringLevel,
      billingImplicationFlag: billingImplicationFlag,
      hasBlockingUnsafeItems: hasBlockingUnsafeItems,
      dwellingInspectionCount: dwellingInspectionCount,
    );

    return {
      'schemaVersion': schemaVersion,
      'methodologyVersion': methodologyVersion,
      'computedAt': DateTime.now().toIso8601String(),

      // Classification
      'networkType': networkType,
      'networkTypeRaw': networkTypeRaw,
      'isHeatNetwork': isHeatNetwork,
      'suppliesDwellings': suppliesDwellings,

      // Scale / context
      'numBlocks': numBlocks,
      'maxFloors': maxFloors,
      'numDwellings': numDwellings,

      // Metering topology
      'hasBulkMeter': hasBulkMeter,
      'hasBlockMeters': hasBlockMeters,
      'meterCountsByType': meterCountsByType,
      'meteringLevel': meteringLevel,
      'billingImplicationFlag': billingImplicationFlag,

      // Plant / distribution
      'generatorCount': generatorCount,
      'generatorTypeCounts': generatorTypeCounts,
      'fuelTypeCounts': fuelTypeCounts,
      'phexCount': phexCount,
      'dhwPlantCount': dhwPlantCount,
      'communalControlCount': communalControlCount,

      // Dwelling sampling
      'dwellingInspectionCount': dwellingInspectionCount,
      ...subMeteringCounts,

      // Safety / escalation
      'observationCount': observationCount,
      'unsafeObservationCount': unsafeObservationCount,
      'unsafeReportCount': unsafeReportCount,
      'unsafeUnreportedCount': unsafeUnreportedCount,
      'hasBlockingUnsafeItems': hasBlockingUnsafeItems,

      // Reporting hooks (portal strategy can map these to narratives/actions)
      'reportingTags': reportingTags,

      // Diagnostics
      if (dataQualityFlags.isNotEmpty) 'dataQualityFlags': dataQualityFlags,
    };
  }

  /// Computes derived metrics using only the submission payload JSON.
  ///
  /// This is used by the Flutter web editor where we don't have access to the
  /// local SQLite-backed `formId` / asset tables.
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
    final unsafeReports = _asListOfMaps(unsafeJson?['unsafeReports']);
    final unreportedUnsafe = _asListOfMaps(
      unsafeJson?['unreportedUnsafeObservations'],
    );

    final meterCountsByType = _countMetersByBaseTypeJson(meters);

    final generatorTypeCounts = <String, int>{};
    final fuelTypeCounts = <String, int>{};
    for (final g in generators) {
      final generatorType = (g['generatorType'] ?? '').toString().trim();
      if (generatorType.isNotEmpty) {
        generatorTypeCounts[generatorType] =
            (generatorTypeCounts[generatorType] ?? 0) + 1;
      }

      final fuelType = (g['fuelType'] ?? '').toString().trim();
      if (fuelType.isNotEmpty) {
        fuelTypeCounts[fuelType] = (fuelTypeCounts[fuelType] ?? 0) + 1;
      }
    }

    final subMeteringCounts = _computeSubMeteringCountsJson(
      dwellingInspections,
    );

    return _computeCore(
      formData: formData,
      meterCountsByType: meterCountsByType,
      generatorCount: generators.length,
      generatorTypeCounts: generatorTypeCounts,
      fuelTypeCounts: fuelTypeCounts,
      phexCount: phex.length,
      dhwPlantCount: dhwPlants.length,
      communalControlCount: communalControls.length,
      dwellingInspectionCount: dwellingInspections.length,
      subMeteringCounts: subMeteringCounts,
      observationCount: observations.length,
      unsafeObservationCount: unsafeObservations.length,
      unsafeReportCount: unsafeReports.length,
      unsafeUnreportedCount: unreportedUnsafe.length,
      methodologyVersion: methodologyVersion,
    );
  }

  static Future<Map<String, dynamic>> compute({
    required int formId,
    required Map<String, dynamic> formData,
    DatabaseHelper? db,
    String methodologyVersion = 'v1',
  }) async {
    final database = db ?? DatabaseHelper.instance;

    final meters = await database.getHeatMeters(formId);
    final generators = await database.getHeatGenerators(formId);
    final phex = await database.getPlateHeatExchangers(formId);
    final dhwPlants = await database.getDhwPlants(formId);
    final communalControls = await database.getCommunalControls(formId);
    final dwellingInspections = await database.getDwellingInspections(formId);

    final observations = await database.getFormObservations(formId);
    final unsafeObservations = await database.getUnsafeObservations(formId);
    final unsafeReports = await database.getUnsafeReports(formId);
    final unreportedUnsafe = await database.getUnreportedUnsafeObservations(
      formId,
    );

    final meterCountsByType = _countMetersByBaseType(meters);

    final generatorTypeCounts = <String, int>{};
    final fuelTypeCounts = <String, int>{};
    for (final g in generators) {
      generatorTypeCounts[g.generatorType] =
          (generatorTypeCounts[g.generatorType] ?? 0) + 1;
      fuelTypeCounts[g.fuelType] = (fuelTypeCounts[g.fuelType] ?? 0) + 1;
    }

    final subMeteringCounts = _computeSubMeteringCounts(dwellingInspections);

    return _computeCore(
      formData: formData,
      meterCountsByType: meterCountsByType,
      generatorCount: generators.length,
      generatorTypeCounts: generatorTypeCounts,
      fuelTypeCounts: fuelTypeCounts,
      phexCount: phex.length,
      dhwPlantCount: dhwPlants.length,
      communalControlCount: communalControls.length,
      dwellingInspectionCount: dwellingInspections.length,
      subMeteringCounts: subMeteringCounts,
      observationCount: observations.length,
      unsafeObservationCount: unsafeObservations.length,
      unsafeReportCount: unsafeReports.length,
      unsafeUnreportedCount: unreportedUnsafe.length,
      methodologyVersion: methodologyVersion,
    );
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
      default:
        return value == null || value.isEmpty ? 'unknown' : 'unknown';
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    return parsed;
  }

  static bool? _toNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();
    if (text == 'yes' || text == 'true' || text == 'y') return true;
    if (text == 'no' || text == 'false' || text == 'n') return false;

    return null;
  }

  static String _baseMeterType(String meterType) {
    final trimmed = meterType.trim();
    final idx = trimmed.indexOf('(');
    if (idx <= 0) return trimmed;
    return trimmed.substring(0, idx).trim();
  }

  static Map<String, int> _countMetersByBaseType(List<HeatMeter> meters) {
    final counts = <String, int>{};
    for (final meter in meters) {
      final key = _baseMeterType(meter.meterType);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, int> _countMetersByBaseTypeJson(
    List<Map<String, dynamic>> meters,
  ) {
    final counts = <String, int>{};
    for (final meter in meters) {
      final meterType = (meter['meterType'] ?? '').toString().trim();
      if (meterType.isEmpty) continue;
      final key = _baseMeterType(meterType);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static String _computeMeteringLevel({
    required Map<String, int> meterCountsByType,
    required bool? hasBulkMeter,
    required bool? hasBlockMeters,
  }) {
    final hasAnyMeters = meterCountsByType.isNotEmpty;
    final inferredBulk = meterCountsByType.keys.any(
      (k) =>
          k.toLowerCase().contains('bulk') || k.toLowerCase().contains('inlet'),
    );
    final inferredBlock = meterCountsByType.keys.any(
      (k) => k.toLowerCase().contains('block'),
    );

    final bulk = (hasBulkMeter == true) || inferredBulk;
    final block = (hasBlockMeters == true) || inferredBlock;

    if (!hasAnyMeters && hasBulkMeter == false && hasBlockMeters == false) {
      return 'none';
    }

    if (bulk && block) return 'bulk_plus_block';
    if (bulk) return 'bulk_only';
    if (block) return 'block_only';

    return hasAnyMeters ? 'present_unspecified' : 'unknown';
  }

  static String _computeBillingImplicationFlag({
    required bool isHeatNetwork,
    required bool hasAnyMeters,
    required bool? hasBulkMeter,
    required bool? hasBlockMeters,
  }) {
    if (!isHeatNetwork) return 'not_applicable';

    final meteringIndicated =
        hasAnyMeters || hasBulkMeter == true || hasBlockMeters == true;

    if (meteringIndicated) return 'metering_present';

    // Heat network, but metering presence not confirmed by the assessment.
    return 'metering_not_confirmed';
  }

  static List<String> _computeReportingTags({
    required bool isHeatNetwork,
    required String meteringLevel,
    required String billingImplicationFlag,
    required bool hasBlockingUnsafeItems,
    required int dwellingInspectionCount,
  }) {
    final tags = <String>[];

    tags.add(isHeatNetwork ? 'IS_HEAT_NETWORK' : 'NOT_HEAT_NETWORK');
    tags.add('METERING_LEVEL_${meteringLevel.toUpperCase()}');
    tags.add('BILLING_${billingImplicationFlag.toUpperCase()}');

    if (hasBlockingUnsafeItems) tags.add('UNSAFE_BLOCKING_ITEMS');
    if (dwellingInspectionCount == 0) tags.add('NO_DWELLING_INSPECTIONS');

    return tags;
  }

  static Map<String, dynamic> _computeSubMeteringCounts(
    List<DwellingInspection> inspections,
  ) {
    int heatingFeasibleYes = 0;
    int heatingFeasibleNo = 0;
    int heatingFeasibleUnknown = 0;

    int dhwFeasibleYes = 0;
    int dhwFeasibleNo = 0;
    int dhwFeasibleUnknown = 0;

    for (final i in inspections) {
      final h = _toNullableBool(i.heatingSubMeterFeasible);
      if (h == true) {
        heatingFeasibleYes++;
      } else if (h == false) {
        heatingFeasibleNo++;
      } else {
        heatingFeasibleUnknown++;
      }

      final d = _toNullableBool(i.dhwSubMeterFeasible);
      if (d == true) {
        dhwFeasibleYes++;
      } else if (d == false) {
        dhwFeasibleNo++;
      } else {
        dhwFeasibleUnknown++;
      }
    }

    return {
      'heatingSubMeterFeasibleYesCount': heatingFeasibleYes,
      'heatingSubMeterFeasibleNoCount': heatingFeasibleNo,
      'heatingSubMeterFeasibleUnknownCount': heatingFeasibleUnknown,
      'dhwSubMeterFeasibleYesCount': dhwFeasibleYes,
      'dhwSubMeterFeasibleNoCount': dhwFeasibleNo,
      'dhwSubMeterFeasibleUnknownCount': dhwFeasibleUnknown,
    };
  }

  static Map<String, dynamic> _computeSubMeteringCountsJson(
    List<Map<String, dynamic>> inspections,
  ) {
    int heatingFeasibleYes = 0;
    int heatingFeasibleNo = 0;
    int heatingFeasibleUnknown = 0;

    int dhwFeasibleYes = 0;
    int dhwFeasibleNo = 0;
    int dhwFeasibleUnknown = 0;

    for (final i in inspections) {
      final h = _toNullableBool(i['heatingSubMeterFeasible']);
      if (h == true) {
        heatingFeasibleYes++;
      } else if (h == false) {
        heatingFeasibleNo++;
      } else {
        heatingFeasibleUnknown++;
      }

      final d = _toNullableBool(i['dhwSubMeterFeasible']);
      if (d == true) {
        dhwFeasibleYes++;
      } else if (d == false) {
        dhwFeasibleNo++;
      } else {
        dhwFeasibleUnknown++;
      }
    }

    return {
      'heatingSubMeterFeasibleYesCount': heatingFeasibleYes,
      'heatingSubMeterFeasibleNoCount': heatingFeasibleNo,
      'heatingSubMeterFeasibleUnknownCount': heatingFeasibleUnknown,
      'dhwSubMeterFeasibleYesCount': dhwFeasibleYes,
      'dhwSubMeterFeasibleNoCount': dhwFeasibleNo,
      'dhwSubMeterFeasibleUnknownCount': dhwFeasibleUnknown,
    };
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _asListOfMapsFromDynamicList(
    List<dynamic>? value,
  ) {
    if (value == null) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }
}
