import 'package:flutter/material.dart';

import '../../../components/form_widgets.dart';
import '../services/hna_derived_metrics_calculator.dart';

class AssessmentSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  /// Optional assets JSON (typically `payload['hna']['assets']`).
  ///
  /// When provided, counts and derived metrics are computed from JSON (no
  /// per-entity SQLite reads).
  final Map<String, dynamic>? assetsJson;

  const AssessmentSummaryScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
    this.assetsJson,
  });

  @override
  State<AssessmentSummaryScreen> createState() =>
      _AssessmentSummaryScreenState();
}

class _AssessmentSummaryScreenState extends State<AssessmentSummaryScreen> {
  bool _isLoading = true;
  bool _isComputingDerivedMetrics = false;
  int _generatorCount = 0;
  int _communalControlCount = 0;
  int _dwellingInspectionCount = 0;
  int _meterCount = 0;
  int _phexCount = 0;

  Map<String, dynamic>? _derivedMetrics;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _computeAndPersistDerivedMetrics();
  }

  Future<void> _loadCounts() async {
    final assets = widget.assetsJson;
    if (assets == null) {
      setState(() => _isLoading = false);
      return;
    }

    final meters = assets['heatMeters'] is List
        ? assets['heatMeters'] as List
        : const [];
    final generators = assets['heatGenerators'] is List
        ? assets['heatGenerators'] as List
        : const [];
    final controls = assets['communalControls'] is List
        ? assets['communalControls'] as List
        : const [];
    final inspections = assets['dwellingInspections'] is List
        ? assets['dwellingInspections'] as List
        : const [];
    final phex = assets['plateHeatExchangers'] is List
        ? assets['plateHeatExchangers'] as List
        : const [];

    setState(() {
      _generatorCount = generators.length;
      _communalControlCount = controls.length;
      _dwellingInspectionCount = inspections.length;
      _meterCount = meters.length;
      _phexCount = phex.length;
      _isLoading = false;
    });
  }

  Future<void> _computeAndPersistDerivedMetrics() async {
    if (_isComputingDerivedMetrics) return;

    // JSON-only: compute from payload fragments rather than SQLite tables.
    if (widget.assetsJson == null) return;

    setState(() => _isComputingDerivedMetrics = true);
    try {
      final metrics = HnaDerivedMetricsCalculator.computeFromPayload(
        formData: widget.formData,
        assetsJson: widget.assetsJson,
      );

      if (!mounted) return;

      setState(() {
        _derivedMetrics = metrics;
        _isComputingDerivedMetrics = false;
      });

      // Persist into form_data so backend upload can parse quickly.
      widget.onDataChanged('derivedMetrics', metrics);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isComputingDerivedMetrics = false);
    }
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountItem(String label, int count, IconData icon) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Assessment Summary',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please review the information below before confirming.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              if (_derivedMetrics != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Derived Metrics',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_isComputingDerivedMetrics)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryItem(
                          'Network Type',
                          (_derivedMetrics!['networkType'] ?? 'N/A').toString(),
                        ),
                        _buildSummaryItem(
                          'Is Heat Network',
                          (_derivedMetrics!['isHeatNetwork'] ?? 'N/A')
                              .toString(),
                        ),
                        _buildSummaryItem(
                          'Metering Level',
                          (_derivedMetrics!['meteringLevel'] ?? 'N/A')
                              .toString(),
                        ),
                        _buildSummaryItem(
                          'Unsafe Outstanding',
                          (_derivedMetrics!['unsafeUnreportedCount'] ?? '0')
                              .toString(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Site Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        'Site Name',
                        (widget.formData['siteName'] ?? 'N/A').toString(),
                      ),
                      _buildSummaryItem(
                        'Address',
                        (widget.formData['streetAddress'] ?? 'N/A').toString(),
                      ),
                      _buildSummaryItem(
                        'Postcode',
                        (widget.formData['postcode'] ?? 'N/A').toString(),
                      ),
                      _buildSummaryItem(
                        'Client',
                        (widget.formData['client'] ?? 'N/A').toString(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Development Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        'Network Type',
                        (widget.formData['meetsHeatNetworkDefinition'] ?? 'N/A')
                            .toString(),
                      ),
                      _buildSummaryItem(
                        'Blocks',
                        (widget.formData['numBlocks'] ?? 0).toString(),
                      ),
                      _buildSummaryItem(
                        'Max Floors',
                        (widget.formData['maxFloors'] ?? 0).toString(),
                      ),
                      _buildSummaryItem(
                        'Dwellings',
                        (widget.formData['numDwellings'] ?? 0).toString(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'System Overview',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        'Dedicated DHW Plant',
                        (widget.formData['dedicatedCommunalDhwPlant'] ?? 'N/A')
                            .toString(),
                      ),
                      if (widget.formData['dedicatedCommunalDhwPlant'] == 'Yes')
                        _buildSummaryItem(
                          'DHW Secondary Return',
                          (widget.formData['dhwSecondaryReturn'] ?? 'N/A')
                              .toString(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Captured Assets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_phexCount > 0)
                _buildCountItem(
                  'Plate Heat Exchangers',
                  _phexCount,
                  Icons.settings_input_component,
                ),
              _buildCountItem(
                'Heat Generators',
                _generatorCount,
                Icons.fireplace,
              ),
              _buildCountItem(
                'Communal Controls',
                _communalControlCount,
                Icons.settings_remote,
              ),
              if (_meterCount > 0)
                _buildCountItem('Heat Meters', _meterCount, Icons.speed),
              _buildCountItem(
                'Dwelling Inspections',
                _dwellingInspectionCount,
                Icons.home,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(text: 'Back', onPressed: widget.onBack),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    text: 'Confirm & Sign',
                    onPressed: widget.onNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
