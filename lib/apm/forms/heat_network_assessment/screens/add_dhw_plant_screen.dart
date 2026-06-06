import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:uuid/uuid.dart';
import '../../../services/platform/image_persistence.dart';

import 'hna_observations_list_screen.dart';

class AddDhwPlantScreen extends StatefulWidget {
  const AddDhwPlantScreen({super.key});

  @override
  State<AddDhwPlantScreen> createState() => _AddDhwPlantScreenState();
}

class _AddDhwPlantScreenState extends State<AddDhwPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _modelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _heatInputController = TextEditingController();

  final _otherTypeController = TextEditingController();
  final _otherFuelController = TextEditingController();

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;
  List<Map<String, dynamic>>? _observationsJson;
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;

  Map<String, dynamic>? _existingItem;

  String? _selectedAge;
  String? _condition;
  String? _operational;

  String? _selectedType;
  bool _isOtherType = false;

  String? _selectedFuel;
  bool _isOtherFuel = false;

  List<XFile> _images = [];
  bool _isLoading = false;

  final List<String> _plantTypes = [
    'Calorifier / Cylinder',
    'DHW heater',
    'Plate heat exchanger (DHW)',
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
        : null;

    final onObsChanged = args['onObservationsChanged'];
    _onObservationsChanged = onObsChanged is Function
        ? (onObsChanged as void Function(List<Map<String, dynamic>>))
        : null;

    final rawItem = args['plant'];
    if (rawItem is Map) {
      _existingItem = Map<String, dynamic>.from(rawItem);
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    if (_existingItem == null) return;

    final item = _existingItem!;
    _makeController.text = (item['make'] ?? '').toString();
    _modelController.text = (item['model'] ?? '').toString();
    _locationController.text = (item['location'] ?? '').toString();
    _selectedAge = _normalizeAgeBand((item['ageRange'] ?? '').toString());
    _serialNumberController.text = (item['serialNumber'] ?? '').toString();
    _capacityController.text = (item['capacity'] ?? '').toString();
    _heatInputController.text = (item['heatInput'] ?? '').toString();

    final condition = (item['condition'] ?? '').toString();
    _condition = condition.trim().isEmpty ? null : condition;

    final operational = (item['operational'] ?? '').toString();
    _operational = operational.trim().isEmpty || operational == 'Unknown'
        ? null
        : operational;

    final plantType = (item['plantType'] ?? '').toString();
    if (_plantTypes.contains(plantType)) {
      _selectedType = plantType;
      _isOtherType = _selectedType == 'Other';
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = plantType;
    }

    final fuel = (item['fuelType'] ?? '').toString();
    if (fuel.trim().isNotEmpty) {
      if (_fuelTypes.contains(fuel)) {
        _selectedFuel = fuel;
        _isOtherFuel = fuel == 'Other';
      } else {
        _selectedFuel = 'Other';
        _isOtherFuel = true;
        _otherFuelController.text = fuel;
      }
    }

    final imagePathsRaw = item['imagePaths'];
    final imagePaths = imagePathsRaw is List
        ? imagePathsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(growable: false)
        : <String>[];
    if (imagePaths.isNotEmpty) {
      _images = imagePaths.map((path) => XFile(path)).toList();
    }

    setState(() {});
  }

  Map<String, String> _getAssetFilterContext() {
    return {'asset_type': 'DHW Plant'};
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

  String _getAssetMakeModel() {
    final makeModel =
        '${_makeController.text.trim()} ${_modelController.text.trim()}'.trim();
    if (makeModel.isNotEmpty) return makeModel;
    if (_existingItem != null) {
      final make = (_existingItem!['make'] ?? '').toString();
      final model = (_existingItem!['model'] ?? '').toString();
      final existing = '$make $model'.trim();
      if (existing.isNotEmpty) return existing;
    }
    return 'DHW Plant';
  }

  Future<void> _manageObservations() async {
    final obs = _observationsJson;
    final onObsChanged = _onObservationsChanged;
    if (obs == null || onObsChanged == null) return;

    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().isEmpty) {
      final saved = await _saveInternal(requireImage: false);
      if (!saved || !mounted) return;
    }

    final itemId = (_existingItem?['id'] ?? '').toString().trim();
    if (itemId.isEmpty) return;

    final makeModel = _getAssetMakeModel();
    final questionText =
        'DHW Plant${makeModel.isNotEmpty ? ' - $makeModel' : ''}';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HnaObservationsListScreen(
          observationsJson: obs,
          onObservationsChanged: (next) {
            _observationsJson = next;
            onObsChanged(next);
          },
          questionReference: 'dhw_$itemId',
          questionText: questionText,
          sectionName: 'On-Site Generation & Distribution',
          assetId: itemId,
          assetType: 'DHW Plant',
          assetMakeModel: makeModel,
        ),
      ),
    );
  }

  Future<void> _saveAndClose() async {
    final success = await _saveInternal();
    if (success && mounted) {
      Navigator.pop(context, _existingItem);
    }
  }

  Future<bool> _saveInternal({bool requireImage = true}) async {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    if (assets == null || onAssetsChanged == null) return false;

    if (_selectedType == null) {
      ApmFeedback.warning(context, 'Please select a plant type');
      return false;
    }

    if (_selectedType == 'DHW heater') {
      if (_selectedFuel == null) {
        ApmFeedback.warning(context, 'Please select a fuel source');
        return false;
      }
      if (_selectedFuel == 'Other' &&
          _otherFuelController.text.trim().isEmpty) {
        ApmFeedback.warning(context, 'Please specify fuel source');
        return false;
      }
    }

    if (_operational == null) {
      ApmFeedback.warning(context, 'Please indicate if visibly operational');
      return false;
    }

    if (!_formKey.currentState!.validate()) return false;

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

      final imagePaths = await persistPickedImagePaths(_images, prefix: 'dhw');

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

      final existingId = (_existingItem?['id'] ?? '').toString().trim();
      final id = existingId.isNotEmpty ? existingId : const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final item = <String, dynamic>{
        'id': id,
        'plantType': _getFinalType(),
        'fuelType': _selectedType == 'DHW heater' ? _getFinalFuel() : null,
        'location': toCamelCase(_locationController.text.trim()),
        'make': toCamelCase(_makeController.text.trim()),
        'model': _modelController.text.trim(),
        'serialNumber': _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        'capacity': _capacityController.text.trim().isEmpty
            ? null
            : _capacityController.text.trim(),
        'heatInput': _heatInputController.text.trim().isEmpty
            ? null
            : _heatInputController.text.trim(),
        'ageRange': _selectedAge ?? '',
        'condition': _condition ?? '',
        'operational': _operational,
        'imagePaths': imagePaths,
        'updatedAt': now,
        'createdAt': (_existingItem?['createdAt'] ?? now),
      };

      final rawList = assets['dhwPlants'];
      final list = rawList is List
          ? rawList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true)
          : <Map<String, dynamic>>[];

      final idx = list.indexWhere((x) => (x['id'] ?? '').toString() == id);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }

      final nextAssets = Map<String, dynamic>.from(assets);
      nextAssets['dhwPlants'] = list;
      onAssetsChanged(nextAssets);
      _assetsJson = nextAssets;

      if (!mounted) return true;
      setState(() {
        _existingItem = item;
        _isLoading = false;
      });

      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ApmFeedback.error(context, 'Error saving DHW plant: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingItem != null;

    return AppScaffold(
      title: isEditing ? 'Edit DHW Plant Item' : 'Add DHW Plant Item',
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Plant Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._plantTypes.map((type) {
                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'Calorifier / Cylinder':
                        icon = Icons.inventory_2;
                        color = Colors.blueGrey;
                        break;
                      case 'DHW heater':
                        icon = Icons.local_fire_department;
                        color = Colors.orange;
                        break;
                      case 'Plate heat exchanger (DHW)':
                        icon = Icons.settings_input_component;
                        color = Colors.purple;
                        break;
                      default:
                        icon = Icons.help_outline;
                        color = Colors.grey;
                    }

                    return AppSelectionCard(
                      title: type,
                      subtitle: 'Select plant type',
                      icon: icon,
                      color: color,
                      selected: _selectedType == type,
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          _isOtherType = type == 'Other';
                          if (type != 'DHW heater') {
                            _selectedFuel = null;
                            _isOtherFuel = false;
                            _otherFuelController.clear();
                          }
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
                  if (_selectedType == 'DHW heater') ...[
                    const SizedBox(height: 24),
                    Text(
                      'Fuel Source',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ..._fuelTypes.map((fuel) {
                      IconData icon;
                      Color color;
                      switch (fuel) {
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
                        title: fuel,
                        subtitle: 'Select fuel source',
                        icon: icon,
                        color: color,
                        selected: _selectedFuel == fuel,
                        onTap: () {
                          setState(() {
                            _selectedFuel = fuel;
                            _isOtherFuel = fuel == 'Other';
                            if (fuel != 'Other') _otherFuelController.clear();
                          });
                        },
                      );
                    }),
                    if (_isOtherFuel)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: AppTextField(
                          label: 'Specify Fuel Source',
                          controller: _otherFuelController,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please specify fuel source'
                              : null,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Equipment Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppAutocompleteField(
                    key: _locationFieldKey,
                    label: 'Location',
                    controller: _locationController,
                    fieldName: 'location',
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppAutocompleteField(
                    key: _makeFieldKey,
                    label: 'Make',
                    controller: _makeController,
                    fieldName: 'make',
                    filterContext: _getAssetFilterContext,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppAutocompleteField(
                    key: _modelFieldKey,
                    label: 'Model',
                    controller: _modelController,
                    fieldName: 'model',
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
                    label: 'Capacity (optional)',
                    controller: _capacityController,
                  ),
                  AppTextField(
                    label: 'Heat Input (kW) (optional)',
                    controller: _heatInputController,
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
                    onChanged: (value) {
                      setState(() => _selectedAge = value);
                    },
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
                        value: 'Unknown',
                        child: Text('Unknown'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _condition = value);
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Visibly Operational?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...['Yes', 'No'].map((val) {
                    return AppSelectionCard(
                      title: val,
                      subtitle: 'Can you tell from sight?',
                      icon: val == 'Yes' ? Icons.check_circle : Icons.cancel,
                      color: val == 'Yes' ? Colors.green : Colors.red,
                      selected: _operational == val,
                      onTap: () {
                        setState(() => _operational = val);
                      },
                    );
                  }),

                  const SizedBox(height: 24),
                  Text(
                    'DHW Plant Photo',
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
                  AppButton(
                    text: 'Add an observation to this DHW plant',
                    onPressed: _manageObservations,
                    icon: Icons.note_add,
                    fullWidth: true,
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

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _locationController.dispose();
    _serialNumberController.dispose();
    _capacityController.dispose();
    _heatInputController.dispose();
    _otherTypeController.dispose();
    _otherFuelController.dispose();
    super.dispose();
  }
}
