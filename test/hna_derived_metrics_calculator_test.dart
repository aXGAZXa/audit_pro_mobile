import 'package:flutter_test/flutter_test.dart';

import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_derived_metrics_calculator.dart';

void main() {
  test('computes schema v4 HNA derived metrics from representative payload data', () {
    final payload = <String, dynamic>{
      'hna': {
        'formData': {
          'meetsHeatNetworkDefinition': 'Communal Heat Network',
          'approximateNetworkAge': '20+ years',
          'numBlocks': 1,
          'hasBulkMeter': 'No',
          'hasBlockMeters': 'No',
        },
        'assets': {
          'heatMeters': <Map<String, dynamic>>[],
          'heatGenerators': <Map<String, dynamic>>[
            {
              'hasIndividualMeter': 'No',
              'condition': 'Poor',
              'operational': 'No',
            },
            {
              'hasIndividualMeter': 'No',
              'condition': 'Good',
              'operational': 'Yes',
            },
          ],
          'plateHeatExchangers': <Map<String, dynamic>>[
            {'condition': 'Poor', 'operational': 'Yes'},
          ],
          'dhwPlants': <Map<String, dynamic>>[
            {'condition': 'Fair', 'operational': 'No'},
          ],
          'communalControls': <Map<String, dynamic>>[],
          'dwellingInspections': <Map<String, dynamic>>[
            {
              'heatingMetered': 'No',
              'dhwMetered': 'No',
              'heatingSubMeterFeasible': 'Yes',
              'dhwSubMeterFeasible': 'No',
            },
            {
              'heatingMetered': 'No',
              'dhwMetered': 'No',
              'heatingSubMeterFeasible': 'No',
              'dhwSubMeterFeasible': 'Further investigation required',
            },
          ],
        },
        'observations': <Map<String, dynamic>>[{}, {}],
        'unsafe': {
          'unsafeObservations': <Map<String, dynamic>>[{}],
          'unsafeReports': <Map<String, dynamic>>[{}],
          'unreportedUnsafeObservations': <Map<String, dynamic>>[{}],
        },
      },
    };

    final hna = payload['hna'] as Map<String, dynamic>;
    final metrics = HnaDerivedMetricsCalculator.computeFromPayload(
      formData: hna['formData'] as Map<String, dynamic>,
      assetsJson: hna['assets'] as Map<String, dynamic>,
      observationsJson: hna['observations'] as List<dynamic>,
      unsafeJson: hna['unsafe'] as Map<String, dynamic>,
    );

    expect(metrics['schemaVersion'], 4);
    expect(metrics['networkCategory'], 3);
    expect(metrics['observationCount'], 2);
    expect(metrics['unsafeCount'], 3);
    expect(metrics['plantInPoorCondition'], 2);
    expect(metrics['nonOperationalPlantAssetCount'], 2);
    expect(metrics['dwellingMeteringFeasibility'], 'Further investigation required');
    expect(metrics['dwellingHeatingMeterFeasibility'], 'Variable feasibility');
    expect(metrics['dwellingDhwMeterFeasibility'], 'Further investigation required');
    expect(metrics['hasDwellingMeterEvidence'], false);
  });
}