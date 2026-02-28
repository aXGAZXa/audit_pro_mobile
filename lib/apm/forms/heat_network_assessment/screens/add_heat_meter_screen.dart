import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../models/heat_meter.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';

class AddHeatMeterScreen extends StatefulWidget {
  const AddHeatMeterScreen({super.key});

  @override
  State<AddHeatMeterScreen> createState() => _AddHeatMeterScreenState();
}

class _AddHeatMeterScreenState extends State<AddHeatMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetMakeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _assetModelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _assetMakeController = TextEditingController();
  final _assetModelController = TextEditingController();
  final _locationController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _meterReadingController = TextEditingController();
  final _blockNameController = TextEditingController();

  int? _formId;
  String? _meterType; // 'Bulk Meter', 'Block Level Meter', etc.
  String? _baseMeterType; // Without brackets
  HeatMeter? _existingMeter;
  String? _selectedAge;
  String? _operational;
  String? _relatedAssetType;
  int? _relatedAssetId;

  List<XFile> _images = [];
  bool _isLoading = false;
  int _observationCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;
      _meterType = args['meterType'] as String? ?? 'Heat Meter';
      _relatedAssetType = args['relatedAssetType'] as String?;
      _relatedAssetId = args['relatedAssetId'] as int?;

      if (args.containsKey('initialLocation') &&
          _locationController.text.isEmpty) {
        _locationController.text = args['initialLocation'] as String;
      }

      _baseMeterType = _meterType;

      final rawMeter = args['meter'];
      if (rawMeter is HeatMeter) {
        _existingMeter = rawMeter;
        _loadExistingData();
      }
    }
  }

  void _loadExistingData() {
    if (_existingMeter == null) return;

    _meterType = _existingMeter!.meterType;
    _relatedAssetType = _existingMeter!.relatedAssetType;
    _relatedAssetId = _existingMeter!.relatedAssetId;

    // Extract base type and block name if applicable
    if (_meterType!.contains('(') && _meterType!.contains(')')) {
      final start = _meterType!.indexOf('(');
      final end = _meterType!.lastIndexOf(')');
      if (end > start) {
        _baseMeterType = _meterType!.substring(0, start).trim();
        _blockNameController.text = _meterType!.substring(start + 1, end);
      } else {
        _baseMeterType = _meterType;
      }
    } else {
      _baseMeterType = _meterType;
    }

    _assetMakeController.text = _existingMeter!.make;
    _assetModelController.text = _existingMeter!.model;
    _locationController.text = _existingMeter!.location;
    _selectedAge = _normalizeAgeBand(_existingMeter!.ageRange);
    _serialNumberController.text = _existingMeter!.serialNumber ?? '';
    _operational = _existingMeter!.operational;
    _meterReadingController.text = _existingMeter!.reading ?? '';

    if (_existingMeter!.imagePaths.isNotEmpty) {
      _images = _existingMeter!.imagePaths.map((path) => XFile(path)).toList();
    }

    _loadObservationCount();
  }

  Future<void> _loadObservationCount() async {
    if (_existingMeter == null || _existingMeter!.id == null) return;

    // Use heat_meter_ID reference pattern
    final questionRef = 'heat_meter_${_existingMeter!.id}';

    final observations = await DatabaseHelper.instance.getQuestionObservations(
      _formId!,
      questionRef,
    );

    if (!mounted) return;
    setState(() {
      _observationCount = observations.length;
    });
  }

  Future<void> _viewObservations() async {
    // If no ID exists, try to save first
    if (_existingMeter == null || _existingMeter!.id == null) {
      final success = await _saveInternal();
      // If save failed or was cancelled, we can't proceed to observations
      if (!success) return;
      if (!mounted) return;
    }

    if (_existingMeter?.id == null) return;

    if (!mounted) return;

    final meterId = _existingMeter!.id!;
    final makeModel =
        '${_assetMakeController.text} ${_assetModelController.text}'.trim();

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': _formId,
        'questionReference': 'heat_meter_$meterId',
        'questionText':
            '$_meterType${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
        'sectionName': 'Heat Meter Observations',
        'assetId': meterId,
        'assetType': _meterType,
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

  Future<bool> _saveInternal() async {
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
      // Save autocomplete suggestions
      await _assetMakeFieldKey.currentState?.saveSuggestion();
      await _assetModelFieldKey.currentState?.saveSuggestion();
      await _locationFieldKey.currentState?.saveSuggestion();

      // Process Images
      final List<String> imagePaths = [];
      final appDir = await getApplicationDocumentsDirectory();

      for (final image in _images) {
        final path = image.path;
        // Check if path is already in app documents directory (existing image)
        if (path.startsWith(appDir.path)) {
          imagePaths.add(path);
        } else {
          // New image - copy it
          final fileName =
              'heat_meter_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.length}.jpg';
          final savedImage = File('${appDir.path}/$fileName');
          await File(path).copy(savedImage.path);
          imagePaths.add(savedImage.path);
        }
      }

      // Helper function to convert to camel case
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

      // Helper for model casing
      String toSmartCamelCase(String text) {
        if (text.isEmpty) return text;
        return text
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              if (word == word.toLowerCase()) {
                return word[0].toUpperCase() + word.substring(1);
              }
              return word;
            })
            .join(' ');
      }

      String finalMeterType = _baseMeterType ?? 'Heat Meter';
      if ((_baseMeterType == 'Block Level Meter' ||
              _baseMeterType == 'Bulk Heat Meter') &&
          _blockNameController.text.isNotEmpty) {
        finalMeterType =
            '$_baseMeterType (${_blockNameController.text.trim()})';
      }

      final meter = HeatMeter(
        id: _existingMeter?.id, // Update if exists
        formId: _formId!,
        meterType: finalMeterType,
        make: toCamelCase(_assetMakeController.text.trim()),
        model: toSmartCamelCase(_assetModelController.text.trim()),
        location: toCamelCase(_locationController.text.trim()),
        ageRange: _selectedAge!,
        serialNumber: _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        operational: _operational!,
        reading: _meterReadingController.text.trim().isEmpty
            ? null
            : _meterReadingController.text.trim(),
        imagePaths: imagePaths,
        relatedAssetType: _relatedAssetType,
        relatedAssetId: _relatedAssetId,
        createdAt: _existingMeter?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedId = await DatabaseHelper.instance.saveHeatMeter(meter);

      // Update our internal state with the new ID and data
      setState(() {
        _existingMeter = HeatMeter(
          id: savedId,
          formId: meter.formId,
          meterType: meter.meterType,
          make: meter.make,
          model: meter.model,
          location: meter.location,
          ageRange: meter.ageRange,
          serialNumber: meter.serialNumber,
          operational: meter.operational,
          reading: meter.reading,
          imagePaths: meter.imagePaths,
          relatedAssetType: meter.relatedAssetType,
          relatedAssetId: meter.relatedAssetId,
          createdAt: meter.createdAt,
          updatedAt: meter.updatedAt,
        );
      });

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving meter: $e')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _assetMakeController.dispose();
    _assetModelController.dispose();
    _locationController.dispose();
    _serialNumberController.dispose();
    _meterReadingController.dispose();
    super.dispose();
  }

  Map<String, String> _getAssetFilterContext() {
    // Use meter type as context for suggestions
    return {'asset_type': _meterType ?? 'Heat Meter'};
  }

  String? _normalizeAgeBand(String? value) {
    switch (value) {
      case 'Up to 5 years':
      case 'Under 5 years':
      case '0-5':
      case '0-5 years':
        return 'Up to 5 years';
      case '5 - 10 years':
      case '5-10 years':
        return '5-10 years';
      case '5-20 years':
      case '5 - 20 years':
      case '10 - 20 years':
      case '10-20 years':
        return '10 plus years';
      case '20+ years':
      case '10+':
        return '10 plus years';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingMeter != null;

    return AppScaffold(
      title: isEditing ? 'Edit $_meterType' : 'Add $_meterType',
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Meter Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  // Meter Type (Disabled, Pre-populated)
                  AppTextField(
                    label: 'Meter Type',
                    controller: TextEditingController(text: _baseMeterType),
                    enabled: false,
                  ),
                  const SizedBox(height: 24),

                  // Block Name / Bulk Meter Description (Conditional)
                  if (_baseMeterType == 'Block Level Meter' ||
                      _baseMeterType == 'Bulk Heat Meter') ...[
                    AppTextField(
                      label: _baseMeterType == 'Block Level Meter'
                          ? 'What block does it serve?'
                          : 'What does this meter serve?',
                      controller: _blockNameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _baseMeterType == 'Block Level Meter'
                              ? 'Please enter the block name'
                              : 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Make
                  AppAutocompleteField(
                    key: _assetMakeFieldKey,
                    label: 'Make',
                    controller: _assetMakeController,
                    fieldName: 'asset_make',
                    filterContext: _getAssetFilterContext,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a make';
                      }
                      return null;
                    },
                  ),

                  // Model
                  AppAutocompleteField(
                    key: _assetModelFieldKey,
                    label: 'Model',
                    controller: _assetModelController,
                    fieldName: 'asset_model',
                    filterContext: () {
                      final context = _getAssetFilterContext();
                      if (_assetMakeController.text.isNotEmpty) {
                        context['asset_make'] = _assetMakeController.text;
                      }
                      return context;
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a model';
                      }
                      return null;
                    },
                  ),

                  // Location
                  AppAutocompleteField(
                    key: _locationFieldKey,
                    label: 'Location',
                    controller: _locationController,
                    fieldName: 'location',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),

                  // Age
                  AppDropdown(
                    label: 'Estimate Age',
                    value: _selectedAge,
                    items: ['Up to 5 years', '5-10 years', '10 plus years']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedAge = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select estimated age';
                      }
                      return null;
                    },
                  ),

                  // Serial Number
                  AppTextField(
                    label: 'Serial Number (if visible)',
                    controller: _serialNumberController,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Visibly Operational?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FormField<String>(
                    initialValue: _operational,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select whether the meter is operational';
                      }
                      return null;
                    },
                    builder: (FormFieldState<String> field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSelectionCard(
                            title: 'Yes',
                            subtitle: 'Can you tell from sight?',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            selected: _operational == 'YES',
                            onTap: () {
                              setState(() {
                                _operational = 'YES';
                                field.didChange('YES');
                              });
                            },
                          ),
                          AppSelectionCard(
                            title: 'No',
                            subtitle: 'Can you tell from sight?',
                            icon: Icons.error_outline,
                            color: Colors.red,
                            selected: _operational == 'NO',
                            onTap: () {
                              setState(() {
                                _operational = 'NO';
                                field.didChange('NO');
                              });
                            },
                          ),
                          if (field.hasError)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                field.errorText!,
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

                  // Meter Reading (Only if operational)
                  if (_operational == 'YES') ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Meter Index Reading',
                      controller: _meterReadingController,
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Meter Image
                  Text(
                    'Meter Photo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppMultiImageCapture(
                    images: _images,
                    maxImages: 1,
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
