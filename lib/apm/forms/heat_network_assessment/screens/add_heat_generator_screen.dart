import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../models/heat_generator.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/screens/add_heat_meter_screen.dart';

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

  int? _formId;
  HeatGenerator? _existingItem;
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
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;

      final rawItem = args['generator'];
      if (rawItem is HeatGenerator) {
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
    _condition = _existingItem!.condition.isEmpty
        ? null
        : _existingItem!.condition;
    _operational = _existingItem!.operational;
    _hasIndividualMeter = _existingItem!.hasIndividualMeter;

    // Handle Type logic
    if (_generatorTypes.contains(_existingItem!.generatorType)) {
      _selectedType = _existingItem!.generatorType;
      _isOtherType =
          _selectedType ==
          'Other'; // Should essentially never be true if saved correctly but safe check
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = _existingItem!.generatorType;
    }

    // Handle Fuel logic
    if (_fuelTypes.contains(_existingItem!.fuelType)) {
      _selectedFuel = _existingItem!.fuelType;
      _isOtherFuel = _selectedFuel == 'Other';
    } else {
      _selectedFuel = 'Other';
      _isOtherFuel = true;
      _otherFuelController.text = _existingItem!.fuelType;
    }

    if (_existingItem!.imagePaths.isNotEmpty) {
      _images = _existingItem!.imagePaths.map((path) => XFile(path)).toList();
    }
    _loadObservationCount();
    _checkLinkedMeter();
  }

  Future<void> _checkLinkedMeter() async {
    if (_existingItem == null || _existingItem!.id == null) return;

    final meter = await DatabaseHelper.instance.getHeatMeterByRelatedAsset(
      _formId!,
      'Heat Generator',
      _existingItem!.id!,
    );

    if (mounted) {
      setState(() {
        _hasLinkedMeter = meter != null;
      });
    }
  }

  Future<void> _loadObservationCount() async {
    if (_existingItem == null || _existingItem!.id == null) return;

    final id = _existingItem!.id!;
    final db = DatabaseHelper.instance;
    final observations = await db.getQuestionObservations(_formId!, 'gen_$id');

    if (!mounted) return;
    setState(() {
      _observationCount = observations.length;
    });
  }

  Future<void> _manageHeatMeter() async {
    // Save first if needed
    if (_existingItem == null || _existingItem!.id == null) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
    }

    // Check again if we have a linked meter
    final meter = await DatabaseHelper.instance.getHeatMeterByRelatedAsset(
      _formId!,
      'Heat Generator',
      _existingItem!.id!,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': _formId,
            'meterType': 'Heat Generator Meter',
            'relatedAssetType': 'Heat Generator',
            'relatedAssetId': _existingItem!.id,
            'meter': meter, // Pass existing meter if found
          },
        ),
      ),
    );

    // Refresh state when back
    _checkLinkedMeter();
  }

  Future<void> _viewObservations() async {
    // If no ID exists, try to save first
    if (_existingItem == null || _existingItem!.id == null) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
      if (!mounted) return;
    }

    if (_existingItem?.id == null) return;

    if (!mounted) return;

    final genId = _existingItem!.id!;
    final ref = 'gen_$genId';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': _formId,
        'questionReference': ref,
        'questionText':
            '${_getFinalType()} Generator${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
        'sectionName': 'Heat Generators',
        'assetId': genId,
        'assetType': 'Heat Generator',
        'assetMakeModel': makeModel.isEmpty ? null : makeModel,
      },
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
      Navigator.pop(context);
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

      final List<String> imagePaths = [];
      final appDir = await getApplicationDocumentsDirectory();

      for (final image in _images) {
        final path = image.path;
        if (path.startsWith(appDir.path)) {
          imagePaths.add(path);
        } else {
          final fileName =
              'gen_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.length}.jpg';
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

      final item = HeatGenerator(
        id: _existingItem?.id,
        formId: _formId!,
        generatorType: _getFinalType(),
        fuelType: _getFinalFuel(),
        location: toCamelCase(_locationController.text.trim()),
        make: toCamelCase(_makeController.text.trim()),
        model: _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        capacity: _capacityController.text.trim().isEmpty
            ? null
            : _capacityController.text.trim(),
        ageRange: _selectedAge!,
        condition: _condition!,
        operational: _operational,
        hasIndividualMeter: _hasIndividualMeter,
        imagePaths: imagePaths,
        createdAt: _existingItem?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedId = await DatabaseHelper.instance.saveHeatGenerator(item);

      // Update the existing item with the new ID and data
      if (mounted) {
        setState(() {
          _existingItem = HeatGenerator(
            id: savedId,
            formId: item.formId,
            generatorType: item.generatorType,
            fuelType: item.fuelType,
            location: item.location,
            make: item.make,
            model: item.model,
            serialNumber: item.serialNumber,
            capacity: item.capacity,
            ageRange: item.ageRange,
            condition: item.condition,
            operational: item.operational,
            hasIndividualMeter: item.hasIndividualMeter,
            imagePaths: item.imagePaths,
          );
          _isLoading = false;
        });
      }

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
