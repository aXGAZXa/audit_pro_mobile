import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../models/communal_control.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';

class AddCommunalControlScreen extends StatefulWidget {
  const AddCommunalControlScreen({super.key});

  @override
  State<AddCommunalControlScreen> createState() =>
      _AddCommunalControlScreenState();
}

class _AddCommunalControlScreenState extends State<AddCommunalControlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _modelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _serialNumberController = TextEditingController();

  // Special controllers for "Other" values
  final _otherTypeController = TextEditingController();

  int? _formId;
  CommunalControl? _existingItem;
  String? _condition;
  String? _operational; // Yes/No

  // To handle the dropdown vs free text logic
  String? _selectedType;
  bool _isOtherType = false;

  int _observationCount = 0;
  List<XFile> _images = [];
  bool _isLoading = false;

  final List<String> _controlTypes = [
    'BMS Panel',
    'Heating Controller',
    'Communal Heat Sensors',
    'Heating Timer/Programmer',
    'Thermostat',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;

      final rawItem = args['control'];
      if (rawItem is CommunalControl) {
        _existingItem = rawItem;
        _loadExistingData();
      }
    }
  }

  void _loadExistingData() {
    if (_existingItem == null) return;

    _makeController.text = _existingItem!.make ?? '';
    _modelController.text = _existingItem!.model ?? '';
    _locationController.text = _existingItem!.location ?? '';
    _serialNumberController.text = _existingItem!.serialNumber ?? '';
    _condition = _existingItem!.condition;
    _operational = _existingItem!.operational == 'Unknown'
        ? null
        : _existingItem!.operational;

    // Handle Type logic
    if (_controlTypes.contains(_existingItem!.controlType)) {
      _selectedType = _existingItem!.controlType;
      _isOtherType = _selectedType == 'Other';
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = _existingItem!.controlType;
    }

    if (_existingItem!.imagePaths.isNotEmpty) {
      _images = _existingItem!.imagePaths.map((path) => XFile(path)).toList();
    }
    _loadObservationCount();
  }

  Future<void> _loadObservationCount() async {
    if (_existingItem == null || _existingItem!.id == null) return;

    final id = _existingItem!.id!;
    final db = DatabaseHelper.instance;
    final observations = await db.getQuestionObservations(_formId!, 'ctrl_$id');

    setState(() {
      _observationCount = observations.length;
    });
  }

  Future<void> _viewObservations() async {
    // If no ID exists, try to save first
    if (_existingItem == null || _existingItem!.id == null) {
      final success = await _saveInternal();
      if (!success) return;
    }

    if (!mounted) return;

    if (_existingItem?.id == null) return;

    final id = _existingItem!.id!;
    final ref = 'ctrl_$id';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': _formId,
        'questionReference': ref,
        'questionText':
            '${_getFinalType()}${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
        'sectionName': 'Communal Controls',
        'assetId': id,
        'assetType': 'Communal Control',
        'assetMakeModel': makeModel.isEmpty ? null : makeModel,
      },
    );
    _loadObservationCount();
  }

  String _getFinalType() {
    if (_isOtherType) return _otherTypeController.text.trim();
    return _selectedType ?? '';
  }

  Map<String, String> _getAssetFilterContext() {
    return {'asset_type': 'Communal Control'};
  }

  Future<void> _saveAndClose() async {
    final success = await _saveInternal();
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _saveInternal() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a control type')),
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
              'ctrl_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.length}.jpg';
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

      final item = CommunalControl(
        id: _existingItem?.id,
        formId: _formId!,
        controlType: _getFinalType(),
        location: toCamelCase(_locationController.text.trim()),
        make: toCamelCase(_makeController.text.trim()),
        model: _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        condition: _condition,
        operational: _operational,
        imagePaths: imagePaths,
        createdAt: _existingItem?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedId = await DatabaseHelper.instance.saveCommunalControl(item);

      // Update the existing item with the new ID and data
      setState(() {
        _existingItem = CommunalControl(
          id: savedId,
          formId: item.formId,
          controlType: item.controlType,
          location: item.location,
          make: item.make,
          model: item.model,
          serialNumber: item.serialNumber,
          condition: item.condition,
          operational: item.operational,
          imagePaths: item.imagePaths,
        );
        _isLoading = false;
      });

      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving control: $e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingItem != null;

    return AppScaffold(
      title: isEditing ? 'Edit Communal Control' : 'Add Communal Control',
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
                child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Control Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._controlTypes.map((type) {
                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'BMS Panel':
                        icon = Icons.dashboard;
                        color = Colors.blue;
                        break;
                      case 'Heating Controller':
                        icon = Icons.settings;
                        color = Colors.orange;
                        break;
                      case 'Communal Heat Sensors':
                        icon = Icons.sensors;
                        color = Colors.purple;
                        break;
                      case 'Heating Timer/Programmer':
                        icon = Icons.schedule;
                        color = Colors.teal;
                        break;
                      case 'Thermostat':
                        icon = Icons.thermostat;
                        color = Colors.green;
                        break;
                      default:
                        icon = Icons.help_outline;
                        color = Colors.grey;
                    }

                    return AppSelectionCard(
                      title: type,
                      subtitle: 'Select control type',
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
                  ),
                  AppTextField(
                    label: 'Serial Number (if visible)',
                    controller: _serialNumberController,
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
                      onTap: () => setState(() => _operational = val),
                    );
                  }),

                  const SizedBox(height: 24),
                  Text(
                    'Control Photo',
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
                  ElevatedButton.icon(
                    onPressed: _viewObservations,
                    icon: Icon(
                      _observationCount > 0 ? Icons.list_alt : Icons.add_comment,
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
