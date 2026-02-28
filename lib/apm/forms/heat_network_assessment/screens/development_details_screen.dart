import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audit_pro_mobile/apm/components/app_info_panel.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'heat_network_guidance_screen.dart';

class DevelopmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  const DevelopmentDetailsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
  });

  @override
  State<DevelopmentDetailsScreen> createState() =>
      _DevelopmentDetailsScreenState();
}

class _DevelopmentDetailsScreenState extends State<DevelopmentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showCustomErrors = false;
  final List<TextInputFormatter> _digitsOnlyFormatter = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  late TextEditingController _blocksController;
  late TextEditingController _maxFloorsController;
  late TextEditingController _dwellingsController;
  late TextEditingController _buildingNatureOtherController;
  late TextEditingController _dwellingTypesOtherController;
  late TextEditingController _supportedFacilitiesOtherController;

  List<String> _buildingNature = [];
  List<String> _dwellingTypes = [];
  List<String> _supportedFacilities = [];

  final List<Map<String, dynamic>> _buildingNatureOptions = [
    {
      'label': 'Residential',
      'icon': Icons.home,
      'color': Colors.blue,
      'subtitle': 'Standard housing',
    },
    {
      'label': 'Care/Nursing Home',
      'icon': Icons.local_hospital,
      'color': Colors.red,
      'subtitle': 'Medical care provided',
    },
    {
      'label': 'Assisted Living',
      'icon': Icons.accessibility_new,
      'color': Colors.orange,
      'subtitle': 'Support available',
    },
    {
      'label': 'Temporary Accomodation',
      'icon': Icons.night_shelter,
      'color': Colors.purple,
      'subtitle': 'Short term housing',
    },
    {
      'label': 'Sheltered Accomodation',
      'icon': Icons.roofing,
      'color': Colors.indigo,
      'subtitle': 'Senior housing with support',
    },
    {
      'label': 'Education',
      'icon': Icons.school,
      'color': Colors.green,
      'subtitle': 'Schools, universities',
    },
    {
      'label': 'Commercial',
      'icon': Icons.store,
      'color': Colors.teal,
      'subtitle': 'Shops, offices',
    },
    {
      'label': 'Industrial',
      'icon': Icons.factory,
      'color': Colors.blueGrey,
      'subtitle': 'Factories, warehouses',
    },
    {
      'label': 'Other',
      'icon': Icons.help_outline,
      'color': Colors.grey,
      'subtitle': 'Any other use',
    },
  ];

  final List<Map<String, dynamic>> _dwellingTypesOptions = [
    {
      'label': 'Flats/Appartments/Houses/Maisonettes',
      'icon': Icons.apartment,
      'color': Colors.blue,
      'subtitle': 'Self-contained units',
    },
    {
      'label': 'Bedsit (own kitchen/Bathroom)',
      'icon': Icons.single_bed,
      'color': Colors.orange,
      'subtitle': 'Single room living',
    },
    {
      'label': 'Rooms - Shared kitchen and/or Bathroom',
      'icon': Icons.meeting_room,
      'color': Colors.brown,
      'subtitle': 'Shared facilities',
    },
    {
      'label': 'Other',
      'icon': Icons.help_outline,
      'color': Colors.grey,
      'subtitle': 'Any other dwelling type',
    },
  ];

  final List<Map<String, dynamic>> _supportedFacilitiesOptions = [
    {
      'label': 'Warden (live-in or regularly on site)',
      'icon': Icons.person,
      'color': Colors.green,
      'subtitle': 'On-site staff providing resident support',
    },
    {
      'label': 'In-dwelling help call facility (building-managed)',
      'icon': Icons.notifications_active,
      'color': Colors.red,
      'subtitle':
          'Emergency call or alarm system installed within individual dwellings',
    },
    {
      'label': 'Nursing or medical staff support',
      'icon': Icons.medical_services,
      'color': Colors.pink,
      'subtitle':
          'Healthcare or assisted living support provided as part of the building operation',
    },
    {
      'label': 'Other (please specify)',
      'icon': Icons.help_outline,
      'color': Colors.grey,
      'subtitle': 'Any other support facility',
    },
  ];

  final List<String> _residentialNatureTypes = [
    'Residential',
    'Care/Nursing Home',
    'Assisted Living',
    'Temporary Accomodation',
    'Sheltered Accomodation',
  ];

  bool get _showDwellingTypesSection =>
      _buildingNature.any((e) => _residentialNatureTypes.contains(e)) ||
      _buildingNature.contains('Other');

  String? _normalizeAgeBand(String? value) {
    switch (value) {
      case 'Up to 5 years':
      case 'Under 5 years':
      case '0-5':
      case '0-5 years':
        return 'Up to 5 years';
      case '5-20 years':
      case '5 - 20 years':
      case '5 - 10 years':
      case '5-10 years':
      case '10 - 20 years':
      case '10-20 years':
        return '5-20 years';
      case '20+ years':
      case '10+':
        return '20+ years';
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    _blocksController = TextEditingController(
      text: widget.formData['numBlocks']?.toString() ?? '',
    );
    _maxFloorsController = TextEditingController(
      text: widget.formData['maxFloors']?.toString() ?? '',
    );
    _dwellingsController = TextEditingController(
      text: widget.formData['numDwellings']?.toString() ?? '',
    );
    _buildingNatureOtherController = TextEditingController(
      text: widget.formData['buildingNatureOther'] ?? '',
    );
    _dwellingTypesOtherController = TextEditingController(
      text: widget.formData['dwellingTypesOther'] ?? '',
    );
    _supportedFacilitiesOtherController = TextEditingController(
      text: widget.formData['supportedFacilitiesOther'] ?? '',
    );

    _buildingNature = List<String>.from(
      widget.formData['buildingNature'] ?? [],
    );
    _dwellingTypes = List<String>.from(widget.formData['dwellingTypes'] ?? []);
    _supportedFacilities = List<String>.from(
      widget.formData['supportedFacilities'] ?? [],
    );
  }

  @override
  void dispose() {
    _blocksController.dispose();
    _maxFloorsController.dispose();
    _dwellingsController.dispose();
    _buildingNatureOtherController.dispose();
    _dwellingTypesOtherController.dispose();
    _supportedFacilitiesOtherController.dispose();
    super.dispose();
  }

  void _saveData() {
    if (_blocksController.text.isNotEmpty) {
      widget.onDataChanged('numBlocks', int.tryParse(_blocksController.text));
    }
    if (_maxFloorsController.text.isNotEmpty) {
      widget.onDataChanged(
        'maxFloors',
        int.tryParse(_maxFloorsController.text),
      );
    }
    if (_dwellingsController.text.isNotEmpty) {
      widget.onDataChanged(
        'numDwellings',
        int.tryParse(_dwellingsController.text),
      );
    }
    if (_buildingNatureOtherController.text.isNotEmpty) {
      widget.onDataChanged(
        'buildingNatureOther',
        _buildingNatureOtherController.text,
      );
    }
    if (_dwellingTypesOtherController.text.isNotEmpty) {
      widget.onDataChanged(
        'dwellingTypesOther',
        _dwellingTypesOtherController.text,
      );
    }
    if (_supportedFacilitiesOtherController.text.isNotEmpty) {
      widget.onDataChanged(
        'supportedFacilitiesOther',
        _supportedFacilitiesOtherController.text,
      );
    }
  }

  void _toggleItem(
    String item,
    List<String> list,
    String key, {
    Function(List<String>)? onUpdate,
  }) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
      widget.onDataChanged(key, list);
      onUpdate?.call(list);
    });
  }

  void _onNext() {
    setState(() {
      _showCustomErrors = true;
    });

    final hasHeatNetworkDefinition =
        widget.formData['meetsHeatNetworkDefinition'] != null &&
        widget.formData['meetsHeatNetworkDefinition'].toString().isNotEmpty;
    final requiresBuildingNature = hasHeatNetworkDefinition;
    final hasBuildingNatureSelection =
        !requiresBuildingNature || _buildingNature.isNotEmpty;
    final isBuildingNatureOtherValid =
        !_buildingNature.contains('Other') ||
        _buildingNatureOtherController.text.trim().isNotEmpty;
    final requiresDwellingTypes = _showDwellingTypesSection;
    final hasDwellingTypeSelection =
        !requiresDwellingTypes || _dwellingTypes.isNotEmpty;
    final isDwellingTypesOtherValid =
        !_dwellingTypes.contains('Other') ||
        _dwellingTypesOtherController.text.trim().isNotEmpty;
    final isCustomValid =
        hasHeatNetworkDefinition &&
        hasBuildingNatureSelection &&
        isBuildingNatureOtherValid &&
        hasDwellingTypeSelection &&
        isDwellingTypesOtherValid;

    if (_formKey.currentState!.validate() && isCustomValid) {
      _saveData();
      widget.onNext();
    }
  }

  void _onBack() {
    _saveData();
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
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
                          'Development Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Does the site meet the definition of a heat network?',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => HeatNetworkGuidanceScreen(
                                onTypeSelected:
                                    (String result, bool isNetwork) {
                                      widget.onDataChanged(
                                        'meetsHeatNetworkDefinition',
                                        result,
                                      );
                                      if (![
                                        'District Heat Network',
                                        'Communal Heat Network',
                                      ].contains(result)) {
                                        widget.onDataChanged(
                                          'approximateNetworkAge',
                                          null,
                                        );
                                      }
                                      Navigator.of(context).pop();
                                    },
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(
                              color:
                                  _showCustomErrors &&
                                      (widget.formData['meetsHeatNetworkDefinition'] ==
                                              null ||
                                          widget
                                              .formData['meetsHeatNetworkDefinition']
                                              .toString()
                                              .isEmpty)
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.formData['meetsHeatNetworkDefinition'] !=
                                        null
                                    ? Icons.check_circle_outline
                                    : Icons.help_outline,
                                color:
                                    widget.formData['meetsHeatNetworkDefinition'] !=
                                        null
                                    ? Colors.green
                                    : Theme.of(context).primaryColor,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.formData['meetsHeatNetworkDefinition'] ??
                                          'Check Definition',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.formData['meetsHeatNetworkDefinition'] !=
                                              null
                                          ? 'Tap to change definition'
                                          : 'Tap to check if this is a heat network',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).disabledColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showCustomErrors &&
                          (widget.formData['meetsHeatNetworkDefinition'] ==
                                  null ||
                              widget.formData['meetsHeatNetworkDefinition']
                                  .toString()
                                  .isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      if ([
                        'District Heat Network',
                        'Communal Heat Network',
                      ].contains(
                        widget.formData['meetsHeatNetworkDefinition'],
                      )) ...[
                        const SizedBox(height: 24),
                        AppDropdown(
                          label: 'Approximate age of network (estimate)',
                          value: _normalizeAgeBand(
                            widget.formData['approximateNetworkAge'],
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Up to 5 years',
                              child: Text('Up to 5 years'),
                            ),
                            DropdownMenuItem(
                              value: '5-20 years',
                              child: Text('5-20 years'),
                            ),
                            DropdownMenuItem(
                              value: '20+ years',
                              child: Text('20+ years'),
                            ),
                          ],
                          onChanged: (value) => widget.onDataChanged(
                            'approximateNetworkAge',
                            value,
                          ),
                          validator: (value) =>
                              value == null ? 'Required' : null,
                        ),
                      ],

                      if (widget.formData['meetsHeatNetworkDefinition'] !=
                              null &&
                          widget.formData['meetsHeatNetworkDefinition']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                        AppTextField(
                          label: 'Number of blocks',
                          controller: _blocksController,
                          keyboardType: TextInputType.number,
                          inputFormatters: _digitsOnlyFormatter,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Required'
                              : null,
                        ),
                        AppTextField(
                          label: 'Maximum number of floors in any one block',
                          controller: _maxFloorsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: _digitsOnlyFormatter,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Required'
                              : null,
                        ),
                        AppTextField(
                          label: 'Number of dwellings (estimate if unknown)',
                          controller: _dwellingsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: _digitsOnlyFormatter,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Required'
                              : null,
                        ),
                        AppDropdown(
                          label: 'Approximate age of the building (estimate)',
                          value: _normalizeAgeBand(
                            widget.formData['approximateBuildingAge'],
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Up to 5 years',
                              child: Text('Up to 5 years'),
                            ),
                            DropdownMenuItem(
                              value: '5-20 years',
                              child: Text('5-20 years'),
                            ),
                            DropdownMenuItem(
                              value: '20+ years',
                              child: Text('20+ years'),
                            ),
                          ],
                          onChanged: (value) => widget.onDataChanged(
                            'approximateBuildingAge',
                            value,
                          ),
                          validator: (value) =>
                              value == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Nature of the building (select ALL that apply)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (_showCustomErrors && _buildingNature.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              'Select at least one option',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        ..._buildingNatureOptions.map(
                          (item) => AppSelectionCard(
                            title: item['label'],
                            subtitle: item['subtitle'],
                            icon: item['icon'],
                            color: item['color'],
                            selected: _buildingNature.contains(item['label']),
                            onTap: () {
                              _toggleItem(
                                item['label'],
                                _buildingNature,
                                'buildingNature',
                                onUpdate: (list) {
                                  if (item['label'] == 'Other' &&
                                      !list.contains('Other')) {
                                    _buildingNatureOtherController.clear();
                                    widget.onDataChanged(
                                      'buildingNatureOther',
                                      null,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        if (_buildingNature.contains('Other'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: AppTextField(
                              label: 'Please specify other use',
                              controller: _buildingNatureOtherController,
                              validator: (value) {
                                if (_buildingNature.contains('Other') &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Please specify other use';
                                }
                                return null;
                              },
                            ),
                          ),

                        if (_showDwellingTypesSection) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          Text(
                            'Dwelling Types (select all that apply)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (_showCustomErrors && _dwellingTypes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                'Select at least one option',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          ..._dwellingTypesOptions.map(
                            (item) => AppSelectionCard(
                              title: item['label'],
                              subtitle: item['subtitle'],
                              icon: item['icon'],
                              color: item['color'],
                              selected: _dwellingTypes.contains(item['label']),
                              onTap: () {
                                _toggleItem(
                                  item['label'],
                                  _dwellingTypes,
                                  'dwellingTypes',
                                  onUpdate: (list) {
                                    if (item['label'] == 'Other' &&
                                        !list.contains('Other')) {
                                      _dwellingTypesOtherController.clear();
                                      widget.onDataChanged(
                                        'dwellingTypesOther',
                                        null,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          if (_dwellingTypes.contains('Other'))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 16,
                              ),
                              child: AppTextField(
                                label: 'Please specify other dwelling type',
                                controller: _dwellingTypesOtherController,
                                validator: (value) {
                                  if (_dwellingTypes.contains('Other') &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Please specify other dwelling type';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
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
                              'Supported Living',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppInfoPanel(
                            title: 'Supported Living Guidance',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The purpose of this section is to identify whether the building operates as supported living.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This applies only where care or support facilities are provided or managed by the building owner or operator and are available within individual dwellings.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'It does not apply to:',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• Standard residential buildings',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '• Concierge or reception services',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '• Emergency call points in communal areas only',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '• Disabled WC alarm cords in shared spaces',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '• Personal alarms or care arranged independently by residents',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Are any of the following supported living facilities provided within individual dwellings?',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select only facilities that are provided or managed by the building owner/operator and are available from within the dwelling.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ..._supportedFacilitiesOptions.map(
                            (item) => AppSelectionCard(
                              title: item['label'],
                              subtitle: item['subtitle'],
                              icon: item['icon'],
                              color: item['color'],
                              selected: _supportedFacilities.contains(
                                item['label'],
                              ),
                              onTap: () {
                                _toggleItem(
                                  item['label'],
                                  _supportedFacilities,
                                  'supportedFacilities',
                                  onUpdate: (list) {
                                    if (item['label'] ==
                                            'Other (please specify)' &&
                                        !list.contains(
                                          'Other (please specify)',
                                        )) {
                                      _supportedFacilitiesOtherController
                                          .clear();
                                      widget.onDataChanged(
                                        'supportedFacilitiesOther',
                                        null,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          if (_supportedFacilities.contains(
                            'Other (please specify)',
                          ))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 16,
                              ),
                              child: AppTextField(
                                label: 'Please specify other facility',
                                controller: _supportedFacilitiesOtherController,
                              ),
                            ),
                        ],
                        if ([
                          'District Heat Network',
                          'Communal Heat Network',
                        ].contains(
                          widget.formData['meetsHeatNetworkDefinition'],
                        ))
                          ...[],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
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
