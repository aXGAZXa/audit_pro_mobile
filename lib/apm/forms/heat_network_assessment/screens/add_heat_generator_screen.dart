import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'hna_observations_list_screen.dart';
import 'package:uuid/uuid.dart';
import 'add_heat_meter_screen.dart';
import '../../../services/platform/image_persistence.dart';

class AddHeatGeneratorScreen extends StatefulWidget {
  const AddHeatGeneratorScreen({super.key});

  @override
  State<AddHeatGeneratorScreen> createState() => _AddHeatGeneratorScreenState();
}

class _AddHeatGeneratorScreenState extends State<AddHeatGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _modelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _capacityController = TextEditingController();

  // Special controllers for "Other" values
  final _otherTypeController = TextEditingController();
  final _otherFuelController = TextEditingController();

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;

  List<Map<String, dynamic>> _observationsJson = <Map<String, dynamic>>[];
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;

  Map<String, dynamic>? _existingItem;
  String? _selectedAge;
  String? _condition;
  String? _operational;
  String? _hasIndividualMeter; // Yes/No

  // To handle the dropdown vs free text logic
  String? _selectedType;
  String? _selectedFuel;
  bool _isOtherType = false;
  bool _isOtherFuel = false;

  int _observationCount = 0;
  bool _hasLinkedMeter = false;

  List<XFile> _images = [];
  bool _isLoading = false;

  final List<String> _generatorTypes = [
    'Boiler',
    'Water Heater',
    'CHP',
    'Biomass',
    'AC Unit',
    'Heat Pump',
    'Other',
  ];

  final List<String> _fuelTypes = [
    'Gas',
    'Oil',
    'LPG',
    'Biomass',
    'Electric',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null || _assetsJson != null) return;

    final assets = args['assetsJson'];
    final onAssetsChanged = args['onAssetsChanged'];
    _assetsJson = assets is Map ? Map<String, dynamic>.from(assets) : null;
    _onAssetsChanged = onAssetsChanged is Function
        ? (onAssetsChanged as void Function(Map<String, dynamic>))
        : null;

    final obs = args['observationsJson'];
    _observationsJson = obs is List
        ? obs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : <Map<String, dynamic>>[];
    final onObsChanged = args['onObservationsChanged'];
    _onObservationsChanged = onObsChanged is Function
        ? (onObsChanged as void Function(List<Map<String, dynamic>>))
        : null;

    final rawItem = args['generator'];
    if (rawItem is Map) {
      _existingItem = Map<String, dynamic>.from(rawItem);
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    if (_existingItem == null) return;

    _makeController.text = (_existingItem!['make'] ?? '').toString();
    _modelController.text = (_existingItem!['model'] ?? '').toString();
    _locationController.text = (_existingItem!['location'] ?? '').toString();
    _selectedAge = _normalizeAgeBand(
      (_existingItem!['ageRange'] ?? '').toString(),
    );
    _serialNumberController.text = (_existingItem!['serialNumber'] ?? '')
        .toString();
    _capacityController.text = (_existingItem!['capacity'] ?? '').toString();
    final conditionRaw = (_existingItem!['condition'] ?? '').toString();
    _condition = conditionRaw.trim().isEmpty ? null : conditionRaw;
    final operationalRaw = (_existingItem!['operational'] ?? '').toString();
    _operational = operationalRaw.trim().isEmpty ? null : operationalRaw;
    final hasMeterRaw = (_existingItem!['hasIndividualMeter'] ?? '').toString();
    _hasIndividualMeter = hasMeterRaw.trim().isEmpty ? null : hasMeterRaw;

    // Handle Type logic
    final existingType = (_existingItem!['generatorType'] ?? '').toString();
    if (_generatorTypes.contains(existingType)) {
      _selectedType = existingType;
      _isOtherType =
          _selectedType ==
          'Other'; // Should essentially never be true if saved correctly but safe check
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = existingType;
    }

    // Handle Fuel logic
    final existingFuel = (_existingItem!['fuelType'] ?? '').toString();
    if (_fuelTypes.contains(existingFuel)) {
      _selectedFuel = existingFuel;
      _isOtherFuel = _selectedFuel == 'Other';
    } else {
      _selectedFuel = 'Other';
      _isOtherFuel = true;
      _otherFuelController.text = existingFuel;
    }

    final imagePaths = _existingItem!['imagePaths'];
    if (imagePaths is List) {
      _images = imagePaths
          .map((e) => e.toString())
          .where((p) => p.trim().isNotEmpty)
          .map((p) => XFile(p))
          .toList(growable: true);
    }
    _loadObservationCount();
    _checkLinkedMeter();
  }

  Future<void> _checkLinkedMeter() async {
    final id = (_existingItem?['id'] ?? '').toString().trim();
    final assets = _assetsJson;
    if (id.isEmpty || assets == null) return;

    final metersRaw = assets['heatMeters'];
    final meters = metersRaw is List
        ? metersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : <Map<String, dynamic>>[];

    final found = meters.any((m) {
      final t = (m['relatedAssetType'] ?? '').toString();
      final rid = (m['relatedAssetId'] ?? '').toString();
      return t == 'Heat Generator' && rid == id;
    });

    if (!mounted) return;
    setState(() => _hasLinkedMeter = found);
  }

  Future<void> _loadObservationCount() async {
    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final ref = 'gen_$id';
    final count = _observationsJson.where((o) {
      final oRef = (o['questionReference'] ?? o['question_reference'] ?? '')
          .toString()
          .trim();
      return oRef == ref;
    }).length;

    if (!mounted) return;
    setState(() => _observationCount = count);
  }

  Future<void> _manageHeatMeter() async {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    if (assets == null || onAssetsChanged == null) return;

    // Ensure generator exists (stable id for relatedAssetId)
    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().trim().isEmpty) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
      if (!mounted) return;
    }

    final genId = (_existingItem?['id'] ?? '').toString().trim();
    if (genId.isEmpty) return;

    final metersRaw = assets['heatMeters'];
    final meters = metersRaw is List
        ? metersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : <Map<String, dynamic>>[];

    final existingIndex = meters.indexWhere((m) {
      final t = (m['relatedAssetType'] ?? '').toString();
      final rid = (m['relatedAssetId'] ?? '').toString();
      return t == 'Heat Generator' && rid == genId;
    });
    final existingMeter = existingIndex >= 0 ? meters[existingIndex] : null;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': null,
            'meterType': 'Heat Generator Meter',
            'meter': existingMeter,
            'relatedAssetType': 'Heat Generator',
            'relatedAssetId': genId,
            'assetsJson': _assetsJson,
            'onAssetsChanged': (Map<String, dynamic> nextAssets) {
              onAssetsChanged(nextAssets);
              _assetsJson = nextAssets;
            },
            'observationsJson': _observationsJson,
            'onObservationsChanged': (List<Map<String, dynamic>> next) {
              _observationsJson = next;
              _onObservationsChanged?.call(next);
            },
          },
        ),
      ),
    );

    _checkLinkedMeter();
  }

  Future<void> _viewObservations() async {
    final onObsChanged = _onObservationsChanged;
    if (onObsChanged == null) return;

    // Ensure generator exists (stable id for questionReference)
    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().trim().isEmpty) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
      if (!mounted) return;
    }

    final genId = (_existingItem?['id'] ?? '').toString().trim();
    if (genId.isEmpty) return;

    final ref = 'gen_$genId';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    final navigator = Navigator.of(context);

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => HnaObservationsListScreen(
          observationsJson: _observationsJson,
          onObservationsChanged: (next) {
            _observationsJson = next;
            onObsChanged(next);
          },
          questionReference: ref,
          questionText:
              '${_getFinalType()} Generator${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
          sectionName: 'Heat Generators',
          assetId: genId,
          assetType: 'Heat Generator',
          assetMakeModel: makeModel.isEmpty ? null : makeModel,
        ),
      ),
    );

    if (!mounted) return;
    _loadObservationCount();
  }

  String _getFinalType() {
    if (_isOtherType) return _otherTypeController.text.trim();
    return _selectedType ?? '';
  }

  String _getFinalFuel() {
    if (_isOtherFuel) return _otherFuelController.text.trim();
    return _selectedFuel ?? '';
  }

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

  Map<String, String> _getAssetFilterContext() {
    return {'asset_type': 'Heat Generator'};
  }

  Future<void> _saveAndClose() async {
    final success = await _saveInternal();
    if (success && mounted) {
      final saved = _existingItem == null
          ? null
          : Map<String, dynamic>.from(_existingItem!);
      Navigator.pop(context, saved);
    }
  }

  Future<bool> _saveInternal({
    bool validateMeter = true,
    bool requireImage = true,
  }) async {
    if (!_formKey.currentState!.validate()) return false;

    // Validate if heat meter is required and present
    if (validateMeter && _hasIndividualMeter == 'Yes' && !_hasLinkedMeter) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text(
            'You indicated this generator has a dedicated heat meter. Please add the heat meter details before saving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    if (requireImage && _images.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please add an image'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    setState(() => _isLoading = true);

    try {
      await _makeFieldKey.currentState?.saveSuggestion();
      await _modelFieldKey.currentState?.saveSuggestion();
      await _locationFieldKey.currentState?.saveSuggestion();

      final imagePaths = await persistPickedImagePaths(_images, prefix: 'hg');

      String toCamelCase(String text) {
        if (text.isEmpty) return text;
        return text
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
      }

      final assets = _assetsJson;
      final onAssetsChanged = _onAssetsChanged;
      if (assets == null || onAssetsChanged == null) {
        throw Exception('Missing assetsJson/onAssetsChanged');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final existing = _existingItem;
      final existingId = (existing?['id'] ?? '').toString().trim();
      final id = existingId.isNotEmpty ? existingId : const Uuid().v4();
      final existingCreatedAt = (existing?['createdAt'] ?? '')
          .toString()
          .trim();

      final item = <String, dynamic>{
        'id': id,
        'generatorType': _getFinalType(),
        'fuelType': _getFinalFuel(),
        'location': toCamelCase(_locationController.text.trim()),
        'make': toCamelCase(_makeController.text.trim()),
        'model': _modelController.text.trim(),
        'serialNumber': _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        'capacity': _capacityController.text.trim().isEmpty
            ? null
            : _capacityController.text.trim(),
        'ageRange': _selectedAge!,
        'condition': _condition!,
        'operational': _operational,
        'hasIndividualMeter': _hasIndividualMeter,
        'imagePaths': imagePaths,
        'createdAt': existingCreatedAt.isNotEmpty ? existingCreatedAt : now,
        'updatedAt': now,
      };

      final raw = assets['heatGenerators'];
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true)
          : <Map<String, dynamic>>[];

      final idx = list.indexWhere((g) => (g['id'] ?? '').toString() == id);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }

      final nextAssets = Map<String, dynamic>.from(assets);
      nextAssets['heatGenerators'] = list;
      onAssetsChanged(nextAssets);
      _assetsJson = nextAssets;

      if (!mounted) return true;
      setState(() {
        _existingItem = item;
        _isLoading = false;
      });

      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving generator: $e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingItem != null;

    return AppScaffold(
      title: isEditing ? 'Edit Heat Generator' : 'Add Heat Generator',
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Generator Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._generatorTypes.map((type) {
                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'Boiler':
                        icon = Icons.water_drop;
                        color = Colors.orange;
                        break;
                      case 'Water Heater':
                        icon = Icons.water;
                        color = Colors.blue;
                        break;
                      case 'CHP':
                        icon = Icons.bolt;
                        color = Colors.purple;
                        break;
                      case 'Biomass':
                        icon = Icons.forest;
                        color = Colors.green;
                        break;
                      case 'AC Unit':
                        icon = Icons.ac_unit;
                        color = Colors.cyan;
                        break;
                      case 'Heat Pump':
                        icon = Icons.air;
                        color = Colors.teal;
                        break;
                      default:
                        icon = Icons.help_outline;
                        color = Colors.grey;
                    }
                    return AppSelectionCard(
                      title: type,
                      subtitle: 'Select this generator type',
                      icon: icon,
                      color: color,
                      selected: _selectedType == type,
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          _isOtherType = type == 'Other';
                        });
                      },
                    );
                  }),
                  if (_isOtherType)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: AppTextField(
                        label: 'Specify Type',
                        controller: _otherTypeController,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please specify type'
                            : null,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Fuel Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._fuelTypes.map((type) {
                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'Gas':
                        icon = Icons.local_fire_department;
                        color = Colors.orange;
                        break;
                      case 'Oil':
                        icon = Icons.water_drop;
                        color = Colors.black87;
                        break;
                      case 'LPG':
                        icon = Icons.cloud;
                        color = Colors.blue;
                        break;
                      case 'Biomass':
                        icon = Icons.forest;
                        color = Colors.green;
                        break;
                      case 'Electric':
                        icon = Icons.bolt;
                        color = Colors.yellow[800]!;
                        break;
                      default:
                        icon = Icons.help_outline;
                        color = Colors.grey;
                    }
                    return AppSelectionCard(
                      title: type,
                      subtitle: 'Select this fuel type',
                      icon: icon,
                      color: color,
                      selected: _selectedFuel == type,
                      onTap: () {
                        setState(() {
                          _selectedFuel = type;
                          _isOtherFuel = type == 'Other';
                        });
                      },
                    );
                  }),
                  if (_isOtherFuel)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppTextField(
                        label: 'Specify Fuel',
                        controller: _otherFuelController,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please specify fuel'
                            : null,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Equipment Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppAutocompleteField(
                    key: _locationFieldKey,
                    controller: _locationController,
                    fieldName: 'location',
                    label: 'Location',
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppAutocompleteField(
                    key: _makeFieldKey,
                    controller: _makeController,
                    fieldName: 'make',
                    label: 'Make',
                    filterContext: _getAssetFilterContext,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppAutocompleteField(
                    key: _modelFieldKey,
                    controller: _modelController,
                    fieldName: 'model',
                    label: 'Model',
                    filterContext: () {
                      final context = _getAssetFilterContext();
                      if (_makeController.text.isNotEmpty) {
                        context['make'] = _makeController.text;
                      }
                      return context;
                    },
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppTextField(
                    label: 'Serial Number (if visible)',
                    controller: _serialNumberController,
                  ),
                  AppTextField(
                    label: 'Capacity (kW)',
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                  ),
                  AppDropdown(
                    label: 'Age Range',
                    value: _selectedAge,
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
                    onChanged: (value) => setState(() => _selectedAge = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Condition',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Visual Condition',
                    value: _condition,
                    items: const [
                      DropdownMenuItem(value: 'Good', child: Text('Good')),
                      DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                      DropdownMenuItem(value: 'Poor', child: Text('Poor')),
                      DropdownMenuItem(
                        value: 'Very Poor',
                        child: Text('Very Poor - Replacement Needed'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _condition = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Visibly Operational?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppSelectionCard(
                    title: 'Yes',
                    subtitle: 'Can you tell from sight?',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    selected: _operational == 'Yes',
                    onTap: () => setState(() => _operational = 'Yes'),
                  ),
                  AppSelectionCard(
                    title: 'No',
                    subtitle: 'Can you tell from sight?',
                    icon: Icons.error_outline,
                    color: Colors.red,
                    selected: _operational == 'No',
                    onTap: () => setState(() => _operational = 'No'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Dedicated Heat Meter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const AppLabel(
                    label: 'Does this generator have a dedicated heat meter?',
                    required: true,
                  ),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _hasIndividualMeter,
                    validator: (value) {
                      if (_hasIndividualMeter == null) {
                        return 'Please make a selection';
                      }
                      return null;
                    },
                    builder: (formState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSelectionCard(
                            title: 'Yes',
                            subtitle: 'It has a dedicated heat meter',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            selected: _hasIndividualMeter == 'Yes',
                            onTap: () {
                              setState(() {
                                _hasIndividualMeter = 'Yes';
                                formState.didChange('Yes');
                              });
                            },
                          ),
                          AppSelectionCard(
                            title: 'No',
                            subtitle: 'No dedicated heat meter',
                            icon: Icons.cancel_outlined,
                            color: Colors.grey,
                            selected: _hasIndividualMeter == 'No',
                            onTap: () {
                              setState(() {
                                _hasIndividualMeter = 'No';
                                formState.didChange('No');
                              });
                            },
                          ),
                          if (formState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 4),
                              child: Text(
                                formState.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_hasIndividualMeter == 'Yes') ...[
                    const SizedBox(height: 16),
                    AppButton(
                      text: _hasLinkedMeter
                          ? 'View Heat Meter'
                          : 'Add Heat Meter',
                      onPressed: _manageHeatMeter,
                      icon: _hasLinkedMeter
                          ? Icons.visibility
                          : Icons.add_circle_outline,
                      fullWidth: true,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Photos Section
                  Text(
                    'Generator Photo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppMultiImageCapture(
                    images: _images,
                    maxImages: 5,
                    onImagesChanged: (newImages) {
                      setState(() => _images = newImages);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Observations
                  ElevatedButton.icon(
                    onPressed: _viewObservations,
                    icon: Icon(
                      _observationCount > 0
                          ? Icons.list_alt
                          : Icons.add_comment,
                      size: 20,
                    ),
                    label: Text(
                      _observationCount > 0
                          ? 'View Observations ($_observationCount)'
                          : 'Add Observations',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: _observationCount > 0
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fixed Bottom Bar
          Container(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[900],
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                          minimumSize: const Size(0, 48),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
