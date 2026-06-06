import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import '../../../database/database_helper.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import '../heat_network_assessment_definition.dart';
import 'hna_observations_list_screen.dart';
import 'package:uuid/uuid.dart';
import '../../../services/platform/image_persistence.dart';

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
  Map<String, dynamic>? _existingMeter;
  String? _selectedAge;
  String? _operational;

  String? _relatedAssetType;
  dynamic _relatedAssetId;

  List<XFile> _images = [];
  bool _isLoading = false;
  int _observationCount = 0;

  Map<String, dynamic>? _assetsJsonArg;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChangedArg;

  List<Map<String, dynamic>>? _observationsJsonArg;
  void Function(List<Map<String, dynamic>> next)? _onObservationsChangedArg;
  bool _didInitArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitArgs) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _didInitArgs = true;
      _formId = args['formId'] as int?;
      _meterType = args['meterType'] as String? ?? 'Heat Meter';
      _relatedAssetType = args['relatedAssetType'] as String?;
      _relatedAssetId = args['relatedAssetId'];

      final assetsArg = args['assetsJson'];
      if (assetsArg is Map) {
        _assetsJsonArg = Map<String, dynamic>.from(assetsArg);
      }
      final onAssetsChanged = args['onAssetsChanged'];
      if (onAssetsChanged is void Function(Map<String, dynamic>)) {
        _onAssetsChangedArg = onAssetsChanged;
      }

      final obsArg = args['observationsJson'];
      if (obsArg is List) {
        _observationsJsonArg = obsArg
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: true);
      }
      final onObsChanged = args['onObservationsChanged'];
      if (onObsChanged is void Function(List<Map<String, dynamic>>)) {
        _onObservationsChangedArg = onObsChanged;
      }

      if (args.containsKey('initialLocation') &&
          _locationController.text.isEmpty) {
        _locationController.text = args['initialLocation'] as String;
      }

      _baseMeterType = _meterType;

      final rawMeter = args['meter'];
      if (rawMeter is Map) {
        _existingMeter = Map<String, dynamic>.from(rawMeter);
        _loadExistingData();
      }
    }
  }

  void _loadExistingData() {
    if (_existingMeter == null) return;

    _meterType = (_existingMeter!['meterType'] ?? '').toString();
    final existingRelatedType = (_existingMeter!['relatedAssetType'] ?? '')
        .toString()
        .trim();
    if (existingRelatedType.isNotEmpty) {
      _relatedAssetType = existingRelatedType;
    }

    final existingRelatedId = _existingMeter!['relatedAssetId'];
    if (existingRelatedId != null &&
        existingRelatedId.toString().trim().isNotEmpty) {
      _relatedAssetId = existingRelatedId;
    }

    // Extract base type and block name if applicable
    if ((_meterType ?? '').contains('(') && (_meterType ?? '').contains(')')) {
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

    _assetMakeController.text = (_existingMeter!['make'] ?? '').toString();
    _assetModelController.text = (_existingMeter!['model'] ?? '').toString();
    _locationController.text = (_existingMeter!['location'] ?? '').toString();
    _selectedAge = _normalizeAgeBand(
      (_existingMeter!['ageRange'] ?? '').toString(),
    );
    _serialNumberController.text = (_existingMeter!['serialNumber'] ?? '')
        .toString();
    _operational = (_existingMeter!['operational'] ?? '').toString();
    if (_operational != null && _operational!.trim().isEmpty) {
      _operational = null;
    }
    _meterReadingController.text = (_existingMeter!['reading'] ?? '')
        .toString();

    final imagePathsRaw = _existingMeter!['imagePaths'];
    if (imagePathsRaw is List && imagePathsRaw.isNotEmpty) {
      _images = imagePathsRaw.map((p) => XFile(p.toString())).toList();
    }

    _loadObservationCount();
  }

  Future<void> _loadObservationCount() async {
    final id = (_existingMeter?['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    final questionRef = 'heat_meter_$id';
    int count = 0;

    final obsRaw = _observationsJsonArg;
    if (obsRaw != null) {
      for (final o in obsRaw) {
        final ref = (o['questionReference'] ?? o['question_reference'] ?? '')
            .toString()
            .trim();
        if (ref == questionRef) count++;
      }
    } else if (_formId != null) {
      final form = await DatabaseHelper.instance.getForm(_formId!);
      if (form == null) return;

      final draftRaw = form['form_data'];
      if (draftRaw is! Map) return;
      final draftDoc = Map<String, dynamic>.from(draftRaw);

      final persistedObsRaw = draftDoc['observations'];
      if (persistedObsRaw is List) {
        for (final o in persistedObsRaw.whereType<Map>()) {
          final ref = (o['questionReference'] ?? o['question_reference'] ?? '')
              .toString()
              .trim();
          if (ref == questionRef) count++;
        }
      }
    }

    if (!mounted) return;
    setState(() => _observationCount = count);
  }

  Future<void> _viewObservations() async {
    // If no ID exists, try to save first
    final currentId = (_existingMeter?['id'] ?? '').toString().trim();
    if (currentId.isEmpty) {
      final savedMeter = await _saveInternal();
      // If save failed or was cancelled, we can't proceed to observations
      if (savedMeter == null) return;
      if (!mounted) return;
    }

    final meterId = (_existingMeter?['id'] ?? '').toString().trim();
    if (meterId.isEmpty) return;

    if (!mounted) return;
    final makeModel =
        '${_assetMakeController.text} ${_assetModelController.text}'.trim();
    final observations = _observationsJsonArg;
    final onChanged = _onObservationsChangedArg;
    if (observations == null || onChanged == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HnaObservationsListScreen(
          observationsJson: observations,
          onObservationsChanged: (List<Map<String, dynamic>> next) {
            _observationsJsonArg = next;
            onChanged(next);
          },
          questionReference: 'heat_meter_$meterId',
          questionText:
              '$_meterType${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
          sectionName: 'Heat Meter Observations',
          assetId: meterId,
          assetType: _meterType,
          assetMakeModel: makeModel.isEmpty ? null : makeModel,
        ),
      ),
    );

    if (!mounted) return;
    _loadObservationCount();
  }

  Future<void> _saveAndClose() async {
    final savedMeter = await _saveInternal();
    if (savedMeter != null && mounted) {
      Navigator.pop(context, Map<String, dynamic>.from(savedMeter));
    }
  }

  Future<Map<String, dynamic>?> _saveInternal() async {
    if (!_formKey.currentState!.validate()) return null;
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
      return null;
    }

    setState(() => _isLoading = true);

    try {
      final cb = _onAssetsChangedArg;
      if (_formId == null && cb == null) {
        throw Exception('Missing formId');
      }

      // Save autocomplete suggestions
      await _assetMakeFieldKey.currentState?.saveSuggestion();
      await _assetModelFieldKey.currentState?.saveSuggestion();
      await _locationFieldKey.currentState?.saveSuggestion();

      // Process Images
      final imagePaths = await persistPickedImagePaths(
        _images,
        prefix: 'heat_meter',
      );

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

      final existingId = (_existingMeter?['id'] ?? '').toString().trim();
      final id = existingId.isEmpty ? const Uuid().v4() : existingId;
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final createdAt =
          (_existingMeter?['createdAt'] ?? _existingMeter?['createdAtUtc'])
              ?.toString();

      final meter = <String, dynamic>{
        'id': id,
        'meterType': finalMeterType,
        'make': toCamelCase(_assetMakeController.text.trim()),
        'model': toSmartCamelCase(_assetModelController.text.trim()),
        'location': toCamelCase(_locationController.text.trim()),
        'ageRange': _selectedAge!,
        'serialNumber': _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        'operational': _operational!,
        'reading': _meterReadingController.text.trim().isEmpty
            ? null
            : _meterReadingController.text.trim(),
        'imagePaths': imagePaths,
        'relatedAssetType': _relatedAssetType,
        'relatedAssetId': _relatedAssetId,
        'createdAt': createdAt ?? nowUtc,
        'updatedAt': nowUtc,
      };

      // Prefer propagating changes up to the parent HNA draft (single JSON
      // document) so parent autosave/submission cannot overwrite meters.
      if (cb != null) {
        final assets = _assetsJsonArg != null
            ? Map<String, dynamic>.from(_assetsJsonArg!)
            : <String, dynamic>{};

        final listRaw = assets['heatMeters'];
        final meters = listRaw is List
            ? listRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(growable: true)
            : <Map<String, dynamic>>[];

        final idx = meters.indexWhere((m) => (m['id'] ?? '').toString() == id);
        if (idx >= 0) {
          meters[idx] = meter;
        } else {
          meters.add(meter);
        }
        assets['heatMeters'] = meters;

        cb(assets);
        _assetsJsonArg = Map<String, dynamic>.from(assets);

        if (mounted) {
          setState(() => _existingMeter = Map<String, dynamic>.from(meter));
        }
        return meter;
      }

      final form = await DatabaseHelper.instance.getForm(_formId!);
      if (form == null) throw Exception('Form not found');

      final draftRaw = form['form_data'];
      if (draftRaw is! Map) throw Exception('Invalid draft doc');
      final draftDoc = Map<String, dynamic>.from(draftRaw);

      final assetsRaw = draftDoc['assets'];
      final assets = assetsRaw is Map
          ? Map<String, dynamic>.from(assetsRaw)
          : <String, dynamic>{};

      final listRaw = assets['heatMeters'];
      final meters = listRaw is List
          ? listRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true)
          : <Map<String, dynamic>>[];

      final idx = meters.indexWhere((m) => (m['id'] ?? '').toString() == id);
      if (idx >= 0) {
        meters[idx] = meter;
      } else {
        meters.add(meter);
      }
      assets['heatMeters'] = meters;
      draftDoc['assets'] = assets;

      final status = (form['status'] ?? 'draft').toString();
      final formType = (form['form_type'] ?? kHeatNetworkAssessmentFormType)
          .toString();
      final uuid = (form['uuid'] ?? '').toString();

      await DatabaseHelper.instance.saveForm(
        id: _formId,
        formType: formType,
        status: status,
        formData: jsonDecode(jsonEncode(draftDoc)) as Map<String, dynamic>,
        uuid: uuid.isEmpty ? null : uuid,
      );

      setState(() => _existingMeter = Map<String, dynamic>.from(meter));

      return meter;
    } catch (e) {
      if (mounted) {
        ApmFeedback.error(context, 'Error saving meter: $e');
      }
      return null;
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
    _blockNameController.dispose();
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
