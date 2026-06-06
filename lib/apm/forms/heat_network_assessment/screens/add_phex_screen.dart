import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'hna_observations_list_screen.dart';
import 'package:uuid/uuid.dart';
import 'add_heat_meter_screen.dart';
import '../../../services/platform/image_persistence.dart';

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

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;

  List<Map<String, dynamic>> _observationsJson = <Map<String, dynamic>>[];
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;

  Map<String, dynamic>? _existingItem;
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

    final rawItem = args['phex'];
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
    final insulationRaw = (_existingItem!['insulationCondition'] ?? '')
        .toString();
    _insulationCondition = insulationRaw.trim().isEmpty ? null : insulationRaw;
    final hasMeterRaw = (_existingItem!['hasIndividualMeter'] ?? '').toString();
    _hasIndividualMeter = hasMeterRaw.trim().isEmpty ? null : hasMeterRaw;

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
      return t == 'Plate Heat Exchanger' && rid == id;
    });

    if (!mounted) return;
    setState(() => _hasLinkedMeter = found);
  }

  Future<void> _loadObservationCount() async {
    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final ref = 'phex_$id';
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

    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().trim().isEmpty) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
      if (!mounted) return;
    }

    final phexId = (_existingItem?['id'] ?? '').toString().trim();
    if (phexId.isEmpty) return;

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
      return t == 'Plate Heat Exchanger' && rid == phexId;
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
            'meterType': 'PHEX Meter',
            'meter': existingMeter,
            'relatedAssetType': 'Plate Heat Exchanger',
            'relatedAssetId': phexId,
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

    if (_existingItem == null ||
        (_existingItem!['id'] ?? '').toString().trim().isEmpty) {
      final success = await _saveInternal(
        validateMeter: false,
        requireImage: false,
      );
      if (!success) return;
      if (!mounted) return;
    }

    final phexId = (_existingItem?['id'] ?? '').toString().trim();
    if (phexId.isEmpty) return;

    final ref = 'phex_$phexId';
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
          questionText: 'PHEX${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
          sectionName: 'Heat Generators - PHEX',
          assetId: phexId,
          assetType: 'Plate Heat Exchanger',
          assetMakeModel: makeModel.isEmpty ? null : makeModel,
        ),
      ),
    );

    if (!mounted) return;
    _loadObservationCount();
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

      final imagePaths = await persistPickedImagePaths(_images, prefix: 'phex');

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
        'insulationCondition': _insulationCondition,
        'hasIndividualMeter': _hasIndividualMeter,
        'imagePaths': imagePaths,
        'createdAt': existingCreatedAt.isNotEmpty ? existingCreatedAt : now,
        'updatedAt': now,
      };

      final raw = assets['plateHeatExchangers'];
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true)
          : <Map<String, dynamic>>[];

      final idx = list.indexWhere((p) => (p['id'] ?? '').toString() == id);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }

      final nextAssets = Map<String, dynamic>.from(assets);
      nextAssets['plateHeatExchangers'] = list;
      onAssetsChanged(nextAssets);
      _assetsJson = nextAssets;

      if (mounted) {
        setState(() {
          _existingItem = item;
        });
      }

      return true;
    } catch (e) {
      if (mounted) {
        ApmFeedback.error(context, 'Error saving PHEX: $e');
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
