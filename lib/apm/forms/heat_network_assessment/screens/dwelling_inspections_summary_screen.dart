import 'package:flutter/material.dart';
import '../../../components/form_widgets.dart';
import 'dwelling_inspection_list_screen.dart';

class DwellingInspectionsSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Map<String, dynamic> assetsJson;
  final void Function(Map<String, dynamic> nextAssets) onAssetsChanged;

  final List<Map<String, dynamic>> observationsJson;
  final void Function(List<Map<String, dynamic>> nextObservations)
  onObservationsChanged;

  const DwellingInspectionsSummaryScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    required this.assetsJson,
    required this.onAssetsChanged,
    required this.observationsJson,
    required this.onObservationsChanged,
  });

  @override
  State<DwellingInspectionsSummaryScreen> createState() =>
      _DwellingInspectionsSummaryScreenState();
}

class _DwellingInspectionsSummaryScreenState
    extends State<DwellingInspectionsSummaryScreen> {
  String? _inspectionsPossible;
  String? _arrangementsConsistent;
  late TextEditingController _unclearDetailsController;

  @override
  void initState() {
    super.initState();
    _inspectionsPossible = widget.formData['dwellingInspectionsPossible'];
    _arrangementsConsistent = widget.formData['dwellingArrangementsConsistent'];
    _unclearDetailsController = TextEditingController(
      text: widget.formData['heatSuppliedUnclearDetails'] ?? '',
    );
  }

  @override
  void dispose() {
    _unclearDetailsController.dispose();
    super.dispose();
  }

  void _saveData() {
    if (_unclearDetailsController.text.isNotEmpty) {
      widget.onDataChanged(
        'heatSuppliedUnclearDetails',
        _unclearDetailsController.text,
      );
    }
  }

  void _onNext() {
    _saveData();
    widget.onNext();
  }

  void _onBack() {
    _saveData();
    widget.onBack();
  }

  void _manageInspections() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DwellingInspectionListScreen(),
        settings: RouteSettings(
          arguments: {
            'assetsJson': widget.assetsJson,
            'onAssetsChanged': widget.onAssetsChanged,
            'observationsJson': widget.observationsJson,
            'onObservationsChanged': widget.onObservationsChanged,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                          "Dwelling Inspections",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Please indicate if you can access individual dwellings to inspect Heat Interface Units (HIUs) or heating systems.",
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Are you able to inspect individual dwellings to determine heating and DHW arrangements?",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      AppSelectionCard(
                        title: 'Yes',
                        subtitle: 'Dwellings are accessible',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        selected: _inspectionsPossible == 'Yes',
                        onTap: () {
                          setState(() {
                            _inspectionsPossible = 'Yes';
                          });
                          widget.onDataChanged(
                            'dwellingInspectionsPossible',
                            'Yes',
                          );
                          // Clear data from 'No' path
                          widget.onDataChanged('heatSuppliedToDwellings', null);
                          _unclearDetailsController.clear();
                          widget.onDataChanged(
                            'heatSuppliedUnclearDetails',
                            null,
                          );
                        },
                      ),
                      AppSelectionCard(
                        title: 'No',
                        subtitle: 'No access to dwellings',
                        icon: Icons.highlight_off,
                        color: Colors.grey,
                        selected: _inspectionsPossible == 'No',
                        onTap: () {
                          setState(() {
                            _inspectionsPossible = 'No';
                            _arrangementsConsistent = null;
                          });
                          widget.onDataChanged(
                            'dwellingInspectionsPossible',
                            'No',
                          );
                          // Clear data from 'Yes' path
                          widget.onDataChanged(
                            'dwellingArrangementsConsistent',
                            null,
                          );
                        },
                      ),
                      if (_inspectionsPossible == 'Yes') ...[
                        const SizedBox(height: 24),
                        AppButton(
                          text: 'Capture Dwelling Inspection',
                          onPressed: _manageInspections,
                          icon: Icons.home,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "If more than one inspection has been carried out, were the in-flat arrangements (system type, heat delivery etc) approximately the same?",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        AppSelectionCard(
                          title: 'Yes',
                          subtitle: 'Arrangements are consistent',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          selected: _arrangementsConsistent == 'Yes',
                          onTap: () {
                            setState(() {
                              _arrangementsConsistent = 'Yes';
                            });
                            widget.onDataChanged(
                              'dwellingArrangementsConsistent',
                              'Yes',
                            );
                          },
                        ),
                        AppSelectionCard(
                          title: 'No',
                          subtitle: 'Significant differences found',
                          icon: Icons.warning_amber,
                          color: Colors.orange,
                          selected: _arrangementsConsistent == 'No',
                          onTap: () {
                            setState(() {
                              _arrangementsConsistent = 'No';
                            });
                            widget.onDataChanged(
                              'dwellingArrangementsConsistent',
                              'No',
                            );
                          },
                        ),
                        AppSelectionCard(
                          title: 'N/A',
                          subtitle: 'Only one inspection performed',
                          icon: Icons.block,
                          color: Colors.grey,
                          selected: _arrangementsConsistent == 'N/A',
                          onTap: () {
                            setState(() {
                              _arrangementsConsistent = 'N/A';
                            });
                            widget.onDataChanged(
                              'dwellingArrangementsConsistent',
                              'N/A',
                            );
                          },
                        ),
                      ],
                      if (_inspectionsPossible == 'No' &&
                          [
                            'District Heat Network',
                            'Communal Heat Network',
                          ].contains(
                            widget.formData['meetsHeatNetworkDefinition'],
                          )) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Is it possible to estimate from the information obtained what is supplied to the dwellings?",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        AppSelectionCard(
                          title: 'Heating only',
                          subtitle: 'Space heating only',
                          icon: Icons.thermostat,
                          color: Colors.orange,
                          selected:
                              widget.formData['heatSuppliedToDwellings'] ==
                              'Heating only',
                          onTap: () {
                            widget.onDataChanged(
                              'heatSuppliedToDwellings',
                              'Heating only',
                            );
                            _unclearDetailsController.clear();
                            widget.onDataChanged(
                              'heatSuppliedUnclearDetails',
                              null,
                            );
                          },
                        ),
                        AppSelectionCard(
                          title: 'DHW only',
                          subtitle: 'Domestic Hot Water only',
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          selected:
                              widget.formData['heatSuppliedToDwellings'] ==
                              'DHW only',
                          onTap: () {
                            widget.onDataChanged(
                              'heatSuppliedToDwellings',
                              'DHW only',
                            );
                            _unclearDetailsController.clear();
                            widget.onDataChanged(
                              'heatSuppliedUnclearDetails',
                              null,
                            );
                          },
                        ),
                        AppSelectionCard(
                          title: 'Heating and DHW',
                          subtitle: 'Both space heating and hot water',
                          icon: Icons.local_fire_department,
                          color: Colors.red,
                          selected:
                              widget.formData['heatSuppliedToDwellings'] ==
                              'Heating and DHW',
                          onTap: () {
                            widget.onDataChanged(
                              'heatSuppliedToDwellings',
                              'Heating and DHW',
                            );
                            _unclearDetailsController.clear();
                            widget.onDataChanged(
                              'heatSuppliedUnclearDetails',
                              null,
                            );
                          },
                        ),
                        AppSelectionCard(
                          title: 'Unclear',
                          subtitle: 'Cannot determine supply type',
                          icon: Icons.help_outline,
                          color: Colors.grey,
                          selected:
                              widget.formData['heatSuppliedToDwellings'] ==
                              'Unclear',
                          onTap: () => widget.onDataChanged(
                            'heatSuppliedToDwellings',
                            'Unclear',
                          ),
                        ),
                        if (widget.formData['heatSuppliedToDwellings'] ==
                            'Unclear')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: AppTextField(
                              label: 'Please provide details',
                              controller: _unclearDetailsController,
                              maxLines: 3,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
            ),
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
                  child: AppButton(text: 'Back', onPressed: _onBack),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(text: 'Next', onPressed: _onNext),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
