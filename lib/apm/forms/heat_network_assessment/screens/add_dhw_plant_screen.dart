import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../models/dhw_plant.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import '../../../components/observations_list_screen.dart';

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

  int? _formId;
  DhwPlant? _existingItem;

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
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;

      final rawItem = args['plant'];
      if (rawItem is DhwPlant) {
        _existingItem = rawItem;
        _loadExistingData();
      }
    }
  }

  void _loadExistingData() {
    if (_existingItem == null) return;

    _makeController.text = _existingItem!.make;
    _modelController.text = _existingItem!.model;
    _locationController.text = _existingItem!.location;
    _selectedAge = _normalizeAgeBand(_existingItem!.ageRange);
    _serialNumberController.text = _existingItem!.serialNumber ?? '';
    _capacityController.text = _existingItem!.capacity ?? '';
    _heatInputController.text = _existingItem!.heatInput ?? '';
    _condition = _existingItem!.condition.isEmpty
        ? null
        : _existingItem!.condition;
    _operational = _existingItem!.operational == 'Unknown'
        ? null
        : _existingItem!.operational;

    if (_plantTypes.contains(_existingItem!.plantType)) {
      _selectedType = _existingItem!.plantType;
      _isOtherType = _selectedType == 'Other';
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = _existingItem!.plantType;
    }

    final fuel = _existingItem!.fuelType;
    if (fuel != null && fuel.isNotEmpty) {
      if (_fuelTypes.contains(fuel)) {
        _selectedFuel = fuel;
        _isOtherFuel = fuel == 'Other';
      } else {
        _selectedFuel = 'Other';
        _isOtherFuel = true;
        _otherFuelController.text = fuel;
      }
    }

    if (_existingItem!.imagePaths.isNotEmpty) {
      _images = _existingItem!.imagePaths.map((path) => XFile(path)).toList();
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
      final existing = '${_existingItem!.make} ${_existingItem!.model}'.trim();
      if (existing.isNotEmpty) return existing;
    }
    return 'DHW Plant';
  }

  Future<void> _manageObservations() async {
    if (_formId == null) return;

    if (_existingItem?.id == null) {
      final saved = await _saveInternal();
      if (!saved || !mounted) return;
    }

    final itemId = _existingItem?.id;
    if (itemId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ObservationsListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': _formId,
            'questionReference': 'dhw_plant_item_$itemId',
            'questionText': 'DHW Plant Observations',
            'sectionName': 'On-Site Generation & Distribution',
            'assetId': itemId,
            'assetType': 'DHW Plant',
            'assetMakeModel': _getAssetMakeModel(),
          },
        ),
      ),
    );
  }

  Future<void> _saveAndClose() async {
    final success = await _saveInternal();
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _saveInternal() async {
    if (_formId == null) return false;

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plant type')),
      );
      return false;
    }

    if (_selectedType == 'DHW heater') {
      if (_selectedFuel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a fuel source')),
        );
        return false;
      }
      if (_selectedFuel == 'Other' &&
          _otherFuelController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify fuel source')),
        );
        return false;
      }
    }

    if (_operational == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please indicate if visibly operational')),
      );
      return false;
    }

    if (!_formKey.currentState!.validate()) return false;

    if (_images.isEmpty) {
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

      final List<String> imagePaths = [];
      final appDir = await getApplicationDocumentsDirectory();

      for (final image in _images) {
        final path = image.path;
        if (path.startsWith(appDir.path)) {
          imagePaths.add(path);
        } else {
          final fileName =
              'dhw_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.length}.jpg';
          final savedImage = File('${appDir.path}/$fileName');
          await File(path).copy(savedImage.path);
          imagePaths.add(savedImage.path);
        }
      }

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

      final item = DhwPlant(
        id: _existingItem?.id,
        formId: _formId!,
        plantType: _getFinalType(),
        fuelType: _selectedType == 'DHW heater' ? _getFinalFuel() : null,
        location: toCamelCase(_locationController.text.trim()),
        make: toCamelCase(_makeController.text.trim()),
        model: _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        capacity: _capacityController.text.trim().isEmpty
            ? null
            : _capacityController.text.trim(),
        heatInput: _heatInputController.text.trim().isEmpty
            ? null
            : _heatInputController.text.trim(),
        ageRange: _selectedAge ?? '',
        condition: _condition ?? '',
        operational: _operational,
        imagePaths: imagePaths,
        createdAt: _existingItem?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedId = await DatabaseHelper.instance.saveDhwPlant(item);

      setState(() {
        _existingItem = DhwPlant(
          id: savedId,
          formId: item.formId,
          plantType: item.plantType,
          fuelType: item.fuelType,
          location: item.location,
          make: item.make,
          model: item.model,
          serialNumber: item.serialNumber,
          capacity: item.capacity,
          heatInput: item.heatInput,
          ageRange: item.ageRange,
          condition: item.condition,
          operational: item.operational,
          imagePaths: item.imagePaths,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );
        _isLoading = false;
      });

      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving DHW plant: $e')));
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
                      icon:
                          val == 'Yes' ? Icons.check_circle : Icons.cancel,
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
    _otherTypeController.dispose();
    _otherFuelController.dispose();
    super.dispose();
  }
}
