import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'package:uuid/uuid.dart';
import '../../../services/platform/image_persistence.dart';

import 'hna_observations_list_screen.dart';

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

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;
  List<Map<String, dynamic>>? _observationsJson;
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;

  Map<String, dynamic>? _existingItem;
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

    final rawItem = args['control'];
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
    _serialNumberController.text = (item['serialNumber'] ?? '').toString();
    _condition = (item['condition'] ?? '').toString().trim().isEmpty
        ? null
        : (item['condition'] ?? '').toString();
    final operational = (item['operational'] ?? '').toString();
    _operational = operational.trim().isEmpty || operational == 'Unknown'
        ? null
        : operational;

    // Handle Type logic
    final controlType = (item['controlType'] ?? '').toString();
    if (_controlTypes.contains(controlType)) {
      _selectedType = controlType;
      _isOtherType = _selectedType == 'Other';
    } else {
      _selectedType = 'Other';
      _isOtherType = true;
      _otherTypeController.text = controlType;
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

    _checkObservationCount();
  }

  void _checkObservationCount() {
    final all = _observationsJson;
    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (all == null || id.isEmpty) {
      if (!mounted) return;
      setState(() => _observationCount = 0);
      return;
    }

    final ref = 'ctrl_$id';
    final count = all.where((o) {
      final oRef = (o['questionReference'] ?? o['question_reference'] ?? '')
          .toString()
          .trim();
      return oRef == ref;
    }).length;

    if (!mounted) return;
    setState(() => _observationCount = count);
  }

  Future<void> _viewObservations() async {
    final obs = _observationsJson;
    final onObsChanged = _onObservationsChanged;
    if (obs == null || onObsChanged == null) return;

    // If no ID exists, try to save first.
    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().isEmpty) {
      final success = await _saveInternal(requireImage: false);
      if (!success) return;
    }

    if (!mounted) return;

    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final ref = 'ctrl_$id';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HnaObservationsListScreen(
          observationsJson: obs,
          onObservationsChanged: (next) {
            _observationsJson = next;
            onObsChanged(next);
          },
          questionReference: ref,
          questionText:
              '${_getFinalType()}${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
          sectionName: 'Communal Controls',
          assetId: id,
          assetType: 'Communal Control',
          assetMakeModel: makeModel.isEmpty ? null : makeModel,
        ),
      ),
    );
    _checkObservationCount();
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
      Navigator.pop(context, _existingItem);
    }
  }

  Future<bool> _saveInternal({bool requireImage = true}) async {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    if (assets == null || onAssetsChanged == null) return false;

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a control type')),
      );
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

      final imagePaths = await persistPickedImagePaths(_images, prefix: 'cc');

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
        'controlType': _getFinalType(),
        'location': toCamelCase(_locationController.text.trim()),
        'make': toCamelCase(_makeController.text.trim()),
        'model': _modelController.text.trim(),
        'serialNumber': _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        'condition': _condition,
        'operational': _operational,
        'imagePaths': imagePaths,
        'updatedAt': now,
        'createdAt': (_existingItem?['createdAt'] ?? now),
      };

      final rawList = assets['communalControls'];
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
      nextAssets['communalControls'] = list;
      onAssetsChanged(nextAssets);
      _assetsJson = nextAssets;

      if (!mounted) return true;
      setState(() {
        _existingItem = item;
        _isLoading = false;
      });

      _checkObservationCount();

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
