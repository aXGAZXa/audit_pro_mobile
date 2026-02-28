import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../components/form_widgets.dart';
import '../services/hna_derived_metrics_calculator.dart';
import 'heat_generator_list_screen.dart';
import 'communal_control_list_screen.dart';
import 'dwelling_inspection_list_screen.dart';
import 'meter_list_screen.dart';
import 'phex_list_screen.dart';

class AssessmentSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  const AssessmentSummaryScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
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
    if (widget.formId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final db = DatabaseHelper.instance;

    try {
      final results = await Future.wait([
        db.getHeatGenerators(widget.formId!),
        db.getCommunalControls(widget.formId!),
        db.getDwellingInspections(widget.formId!),
        // Wrap potentially missing methods in Future.value([]) or try-catch blocks if needed
        // Since we can't easily wrap individual futures in a list with reliable error handling for just one,
        // we will proceed assuming these exist or catch the whole block.
        // For meters and phex, let's play safe and fetch them separately if unsure,
        // but parallelizing the main ones helps.
      ]);

      final generators = results[0] as List;
      final controls = results[1] as List;
      final inspections = results[2] as List;

      List<dynamic> meters = [];
      try {
        meters = await db.getHeatMeters(widget.formId!);
      } catch (_) {}

      List<dynamic> phex = [];
      try {
        final phexData = await db.getPlateHeatExchangers(widget.formId!);
        phex = phexData;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _generatorCount = generators.length;
          _communalControlCount = controls.length;
          _dwellingInspectionCount = inspections.length;
          _meterCount = meters.length;
          _phexCount = phex.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _computeAndPersistDerivedMetrics() async {
    if (widget.formId == null) return;
    if (_isComputingDerivedMetrics) return;

    setState(() => _isComputingDerivedMetrics = true);
    try {
      final metrics = await HnaDerivedMetricsCalculator.compute(
        formId: widget.formId!,
        formData: widget.formData,
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

  Widget _buildCountItem(
    String label,
    int count,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              if (onTap != null) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).disabledColor,
                ),
              ],
            ],
          ),
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

              // Site Details Section
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
                        widget.formData['siteName'] ?? 'N/A',
                      ),
                      _buildSummaryItem(
                        'Address',
                        widget.formData['streetAddress'] ?? 'N/A',
                      ),
                      _buildSummaryItem(
                        'Postcode',
                        widget.formData['postcode'] ?? 'N/A',
                      ),
                      _buildSummaryItem(
                        'Client',
                        widget.formData['client'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Development Details
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
                        widget.formData['meetsHeatNetworkDefinition'] ?? 'N/A',
                      ),
                      _buildSummaryItem(
                        'Blocks',
                        widget.formData['numBlocks']?.toString() ?? '0',
                      ),
                      _buildSummaryItem(
                        'Max Floors',
                        widget.formData['maxFloors']?.toString() ?? '0',
                      ),
                      _buildSummaryItem(
                        'Dwellings',
                        widget.formData['numDwellings']?.toString() ?? '0',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // System Configuration
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
                        widget.formData['dedicatedCommunalDhwPlant'] ?? 'N/A',
                      ),
                      if (widget.formData['dedicatedCommunalDhwPlant'] == 'Yes')
                        _buildSummaryItem(
                          'DHW Secondary Return',
                          widget.formData['dhwSecondaryReturn'] ?? 'N/A',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Assets Summary
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhexListScreen(),
                      settings: RouteSettings(
                        arguments: {'formId': widget.formId, 'readOnly': true},
                      ),
                    ),
                  ),
                ),
              _buildCountItem(
                'Heat Generators',
                _generatorCount,
                Icons.fireplace,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HeatGeneratorListScreen(),
                    settings: RouteSettings(
                      arguments: {'formId': widget.formId, 'readOnly': true},
                    ),
                  ),
                ),
              ),
              _buildCountItem(
                'Communal Controls',
                _communalControlCount,
                Icons.settings_remote,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunalControlListScreen(),
                    settings: RouteSettings(
                      arguments: {'formId': widget.formId, 'readOnly': true},
                    ),
                  ),
                ),
              ),
              if (_meterCount > 0)
                _buildCountItem(
                  'Heat Meters',
                  _meterCount,
                  Icons.speed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MeterListScreen(),
                      settings: RouteSettings(
                        arguments: {
                          'formId': widget.formId,
                          'readOnly': true,
                          'networkType':
                              null, // Passing null so it loads ALL meters if readOnly logic handles it
                        },
                      ),
                    ),
                  ),
                ),
              _buildCountItem(
                'Dwelling Inspections',
                _dwellingInspectionCount,
                Icons.home,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DwellingInspectionListScreen(),
                    settings: RouteSettings(
                      arguments: {'formId': widget.formId, 'readOnly': true},
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),

        // Bottom Bar
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
                    // Typically 'Confirm' implies proceeding to the next step which is signature
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
