import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/platform/image_persistence.dart';
import '../database/database_helper.dart';
import '../components/app_scaffold.dart';
import '../components/app_autocomplete_field.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetMakeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _assetModelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _assetMakeController = TextEditingController();
  final _assetModelController = TextEditingController();
  final _locationController = TextEditingController();
  final _estimateAgeController = TextEditingController();

  int? _formId;
  Map<String, dynamic>? _existingAsset;
  List<Map<String, dynamic>> _assetTypes = [];
  List<Map<String, dynamic>> _assetStatuses = [];
  int? _selectedAssetTypeId;
  String? _selectedStatus;
  String? _operational;
  String? _visualCondition;
  List<XFile> _images = [];
  bool _isLoading = false;
  bool _loadingAssetTypes = true;
  int _observationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAssetTypes();
    _loadAssetStatuses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _formId == null) {
      _formId = args['formId'] as int?;
      _existingAsset = args['asset'] as Map<String, dynamic>?;
      if (_existingAsset != null) {
        _loadExistingData();
      }
    }
  }

  Future<void> _loadAssetTypes() async {
    setState(() => _loadingAssetTypes = true);
    final assetTypes = await DatabaseHelper.instance.getAssetTypes();
    setState(() {
      _assetTypes = assetTypes;
      _loadingAssetTypes = false;
    });
  }

  Future<void> _loadAssetStatuses() async {
    final statuses = await DatabaseHelper.instance.getCollectionItems(
      'asset_statuses',
    );
    setState(() {
      _assetStatuses = statuses;
    });
  }

  void _loadExistingData() {
    if (_existingAsset == null) return;

    _selectedAssetTypeId = _existingAsset!['asset_type_id'] as int?;
    _assetMakeController.text = _existingAsset!['asset_make'] as String? ?? '';
    _assetModelController.text =
        _existingAsset!['asset_model'] as String? ?? '';
    _locationController.text = _existingAsset!['location'] as String? ?? '';
    _estimateAgeController.text =
        _existingAsset!['estimate_age']?.toString() ?? '';
    _operational = _existingAsset!['operational'] as String?;
    _selectedStatus = _existingAsset!['status'] as String?;
    _visualCondition = _existingAsset!['visual_condition'] as String?;

    final images = _existingAsset!['images'] as List<dynamic>?;
    if (images != null) {
      _images = images.map((path) => XFile(path.toString())).toList();
    }

    // Load observation count if editing
    _loadObservationCount();
  }

  Future<void> _loadObservationCount() async {
    if (_existingAsset == null) return;
    final assetId = _existingAsset!['id'] as int?;
    if (assetId == null) return;

    final observations = await DatabaseHelper.instance.getQuestionObservations(
      _formId!,
      'asset_$assetId',
    );
    setState(() {
      _observationCount = observations.length;
    });
  }

  void _viewObservations() {
    if (_existingAsset == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text(
            'Please save the asset first before adding observations',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final assetId = _existingAsset!['id'] as int;
    final assetTypeDetails =
        _existingAsset!['asset_type_details'] as Map<String, dynamic>?;
    final assetTypeName = assetTypeDetails?['asset_type'] as String? ?? 'Asset';
    final makeModel =
        '${_assetMakeController.text} ${_assetModelController.text}'.trim();

    Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': _formId,
        'questionReference': 'asset_$assetId',
        'questionText':
            '$assetTypeName${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
        'sectionName': 'Asset Observations',
        'assetId': assetId,
        'assetType': assetTypeName,
        'assetMakeModel': makeModel.isEmpty ? null : makeModel,
      },
    ).then((_) {
      _loadObservationCount();
    });
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAssetTypeId == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please select an asset type'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (_images.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please add at least one image'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save autocomplete suggestions for valid entries
      await _assetMakeFieldKey.currentState?.saveSuggestion();
      await _assetModelFieldKey.currentState?.saveSuggestion();
      await _locationFieldKey.currentState?.saveSuggestion();

      final imagePaths = await persistPickedImagePaths(
        _images,
        prefix: 'asset',
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

      // Converts only fully lowercase words to title case, preserves existing uppercase
      String toSmartCamelCase(String text) {
        if (text.isEmpty) return text;
        return text
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              // Only capitalize if the word is all lowercase
              if (word == word.toLowerCase()) {
                return word[0].toUpperCase() + word.substring(1);
              }
              // Otherwise, keep it as-is (preserves GB162, etc.)
              return word;
            })
            .join(' ');
      }

      await DatabaseHelper.instance.saveAsset(
        id: _existingAsset?['id'] as int?,
        formId: _formId!,
        assetTypeId: _selectedAssetTypeId!,
        assetMake: _assetMakeController.text.isEmpty
            ? null
            : toCamelCase(_assetMakeController.text.trim()),
        assetModel: _assetModelController.text.isEmpty
            ? null
            : toSmartCamelCase(_assetModelController.text.trim()),
        location: _locationController.text.isEmpty
            ? null
            : toCamelCase(_locationController.text.trim()),
        estimateAge: _estimateAgeController.text.isEmpty
            ? null
            : int.tryParse(_estimateAgeController.text),
        operational: _operational,
        status: _selectedStatus!,
        visualCondition: _visualCondition!,
        imagePaths: imagePaths.isEmpty ? null : imagePaths,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving asset: $e')));
      }
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
    _estimateAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingAsset != null;

    return AppScaffold(
      title: isEditing ? 'Edit Asset' : 'Add Asset',
      body: _loadingAssetTypes
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Asset Type
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedAssetTypeId,
                                  decoration: const InputDecoration(
                                    labelText: 'Asset Type',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _assetTypes.map((assetType) {
                                    return DropdownMenuItem<int>(
                                      value: assetType['id'] as int,
                                      child: Text(
                                        assetType['asset_type'] as String,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(
                                      () => _selectedAssetTypeId = value,
                                    );
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select an asset type';
                                    }
                                    return null;
                                  },
                                ),
                                if (_assetTypes.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'No asset types available. Go to Settings > Manage Asset Types to add one.',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Make (with autocomplete)
                                AppAutocompleteField(
                                  key: _assetMakeFieldKey,
                                  label: 'Make',
                                  controller: _assetMakeController,
                                  fieldName: 'asset_make',
                                  filterContext: () {
                                    if (_selectedAssetTypeId != null) {
                                      final selectedType = _assetTypes
                                          .firstWhere(
                                            (t) =>
                                                t['id'] == _selectedAssetTypeId,
                                          );
                                      return {
                                        'asset_type':
                                            selectedType['asset_type']
                                                as String,
                                      };
                                    }
                                    return {};
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a make';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Model (with autocomplete)
                                AppAutocompleteField(
                                  key: _assetModelFieldKey,
                                  label: 'Model',
                                  controller: _assetModelController,
                                  fieldName: 'asset_model',
                                  filterContext: () {
                                    final context = <String, String>{};
                                    if (_selectedAssetTypeId != null) {
                                      final selectedType = _assetTypes
                                          .firstWhere(
                                            (t) =>
                                                t['id'] == _selectedAssetTypeId,
                                          );
                                      context['asset_type'] =
                                          selectedType['asset_type'] as String;
                                    }
                                    if (_assetMakeController.text.isNotEmpty) {
                                      context['asset_make'] =
                                          _assetMakeController.text;
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
                                const SizedBox(height: 16),

                                // Location (with autocomplete - no filtering)
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
                                const SizedBox(height: 16),

                                // Age
                                TextFormField(
                                  controller: _estimateAgeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Age (years)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter the age';
                                    }
                                    final age = int.tryParse(value);
                                    if (age == null || age < 0) {
                                      return 'Please enter a valid age';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Operational
                                FormField<String>(
                                  initialValue: _operational,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select whether the asset is operational';
                                    }
                                    return null;
                                  },
                                  builder: (FormFieldState<String> field) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Operational',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        RadioGroup<String>(
                                          groupValue: _operational,
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _operational = value;
                                                field.didChange(value);
                                              });
                                            }
                                          },
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: RadioListTile<String>(
                                                  title: const Text('YES'),
                                                  value: 'YES',
                                                ),
                                              ),
                                              Expanded(
                                                child: RadioListTile<String>(
                                                  title: const Text('NO'),
                                                  value: 'NO',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (field.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 16,
                                              top: 4,
                                            ),
                                            child: Text(
                                              field.errorText!,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Status
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _assetStatuses
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status['name'] as String,
                                          child: Text(status['name'] as String),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedStatus = value);
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a status';
                                    }
                                    return null;
                                  },
                                ),
                                if (_assetStatuses.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'No asset statuses available. Go to Settings > Manage Asset Statuses to add one.',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Visual Condition
                                DropdownButtonFormField<String>(
                                  initialValue: _visualCondition,
                                  decoration: const InputDecoration(
                                    labelText: 'Visual Condition',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Good',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green[600],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Good'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Fair',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.amber[600],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Fair'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Poor',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red[600],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Poor'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _visualCondition = value);
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a visual condition';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
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
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                    backgroundColor: _observationCount > 0
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons - Fixed at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Cancel Button
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
                        // Save Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveAsset,
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
                                : Text(isEditing ? 'UPDATE' : 'SAVE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
