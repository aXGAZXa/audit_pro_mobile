import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../models/plate_heat_exchanger.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';

import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/screens/add_heat_meter_screen.dart';

class AddPhexScreen extends StatefulWidget {
  const AddPhexScreen({super.key});

  @override
  State<AddPhexScreen> createState() => _AddPhexScreenState();
}

class _AddPhexScreenState extends State<AddPhexScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _modelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _capacityController = TextEditingController();

  int? _formId;
  PlateHeatExchanger? _existingItem;
  String? _selectedAge;
  String? _condition;
  String? _insulationCondition;
  String? _hasIndividualMeter; // Yes/No

  int _observationCount = 0;
  bool _hasLinkedMeter = false;

  List<XFile> _images = [];
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;

      final rawItem = args['phex'];
      if (rawItem is PlateHeatExchanger) {
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
    _condition = _existingItem!.condition;
    _insulationCondition = _existingItem!.insulationCondition;
    _hasIndividualMeter = _existingItem!.hasIndividualMeter;

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
      'Plate Heat Exchanger',
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
    final observations = await db.getQuestionObservations(_formId!, 'phex_$id');

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
      'Plate Heat Exchanger',
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
            'meterType': 'PHEX Meter',
            'relatedAssetType': 'Plate Heat Exchanger',
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
      // If save failed or was cancelled, we can't proceed to observations
      if (!success) return;
      if (!mounted) return;
    }

    if (_existingItem?.id == null) return;

    if (!mounted) return;

    final phexId = _existingItem!.id!;
    final ref = 'phex_$phexId';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': _formId,
        'questionReference': ref,
        'questionText': 'PHEX${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
        'sectionName': 'Heat Generators - PHEX',
        'assetId': phexId,
        'assetType': 'Plate Heat Exchanger',
        'assetMakeModel': makeModel.isEmpty ? null : makeModel,
      },
    );

    if (!mounted) return;
    _loadObservationCount();
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
            'You indicated this PHEX has a dedicated heat meter. Please add the heat meter details before saving.',
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
              'phex_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.length}.jpg';
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

      final item = PlateHeatExchanger(
        id: _existingItem?.id,
        formId: _formId!,
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
        insulationCondition: _insulationCondition,
        hasIndividualMeter: _hasIndividualMeter, // Save the new field
        imagePaths: imagePaths,
        createdAt: _existingItem?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedId = await DatabaseHelper.instance.savePlateHeatExchanger(
        item,
      );

      // Update the existing item with the new ID and data
      setState(() {
        _existingItem = PlateHeatExchanger(
          id: savedId,
          formId: item.formId,
          location: item.location,
          make: item.make,
          model: item.model,
          serialNumber: item.serialNumber,
          capacity: item.capacity,
          ageRange: item.ageRange,
          condition: item.condition,
          insulationCondition: item.insulationCondition,
          // Copy other optional fields that might be null in 'item' but aren't changed here
          // (though in this form we create a fresh item object so passing what we have is correct)
          freeOfLeaks: item.freeOfLeaks,
          hasIsolationValves: item.hasIsolationValves,
          hasTempGauges: item.hasTempGauges,
          hasIndividualMeter: item.hasIndividualMeter, // This is updated
          imagePaths: item.imagePaths,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );
      });

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving PHEX: $e')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, String> _getAssetFilterContext() {
    return {'asset_type': 'Plate Heat Exchanger'};
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

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingItem != null;

    return AppScaffold(
      title: isEditing ? 'Edit PHEX' : 'Add PHEX',
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Equipment Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppAutocompleteField(
                    key: _locationFieldKey,
                    label: 'Location (e.g. Block A Plant Room)',
                    controller: _locationController,
                    fieldName: 'location',
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  AppAutocompleteField(
                    key: _makeFieldKey,
                    label: 'Make',
                    controller: _makeController,
                    fieldName: 'asset_make',
                    filterContext: _getAssetFilterContext,
                  ),
                  AppAutocompleteField(
                    key: _modelFieldKey,
                    label: 'Model',
                    controller: _modelController,
                    fieldName: 'asset_model',
                    filterContext: () {
                      final context = _getAssetFilterContext();
                      if (_makeController.text.isNotEmpty) {
                        context['asset_make'] = _makeController.text;
                      }
                      return context;
                    },
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
                    label: 'Estimated Age',
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
                    validator: (value) =>
                        value == null ? 'Please select estimated age' : null,
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
                        value: 'Not Operational',
                        child: Text('Not Operational'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _condition = value),
                    validator: (value) =>
                        value == null ? 'Please select condition' : null,
                  ),
                  AppDropdown(
                    label: 'Insulation Condition',
                    value: _insulationCondition,
                    items: const [
                      DropdownMenuItem(value: 'Good', child: Text('Good')),
                      DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                      DropdownMenuItem(value: 'Poor', child: Text('Poor')),
                      DropdownMenuItem(
                        value: 'Missing',
                        child: Text('Missing'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _insulationCondition = value),
                    validator: (value) => value == null
                        ? 'Please select insulation condition'
                        : null,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Dedicated Heat Meter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const AppLabel(
                    label: 'Is this PHEX fitted with a dedicated heat meter?',
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
                  Text(
                    'PHEX Photo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppMultiImageCapture(
                    images: _images,
                    maxImages: 2,
                    onImagesChanged: (newImages) {
                      setState(() => _images = newImages);
                    },
                  ),

                  const SizedBox(height: 16),
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
