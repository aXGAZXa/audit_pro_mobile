import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../components/app_scaffold.dart';
import '../../../components/app_autocomplete_field.dart';
import '../../../components/form_widgets.dart';

class WebHeatMeterListEditorScreen extends StatefulWidget {
  const WebHeatMeterListEditorScreen({
    super.key,
    required this.title,
    required this.baseMeterType,
    required this.heatMeters,
  });

  final String title;
  final String baseMeterType;
  final List<Map<String, dynamic>> heatMeters;

  @override
  State<WebHeatMeterListEditorScreen> createState() =>
      _WebHeatMeterListEditorScreenState();
}

class _WebHeatMeterListEditorScreenState
    extends State<WebHeatMeterListEditorScreen> {
  late final List<Map<String, dynamic>> _meters = widget.heatMeters
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: true);

  String _displayTitle(Map<String, dynamic> m) {
    final make = (m['make'] ?? '').toString().trim();
    final model = (m['model'] ?? '').toString().trim();
    final combined = [make, model].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'Meter' : combined;
  }

  String? _displaySubtitle(Map<String, dynamic> m) {
    final location = (m['location'] ?? '').toString().trim();
    return location.isEmpty ? null : location;
  }

  bool _matchesBaseType(Map<String, dynamic> m) {
    final meterType = (m['meterType'] ?? '').toString();
    if (meterType == widget.baseMeterType) return true;
    if (meterType.startsWith('${widget.baseMeterType} (')) return true;
    return false;
  }

  List<Map<String, dynamic>> get _filteredMeters {
    return _meters.where(_matchesBaseType).toList(growable: false);
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => WebHeatMeterEditorScreen(
          baseMeterType: widget.baseMeterType,
          existing: existing,
        ),
      ),
    );

    if (saved == null) return;

    setState(() {
      final id = (saved['id'] ?? '').toString();
      final idx = _meters.indexWhere((m) => (m['id'] ?? '').toString() == id);
      if (idx >= 0) {
        _meters[idx] = saved;
      } else {
        _meters.add(saved);
      }
    });
  }

  Future<void> _delete(Map<String, dynamic> meter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meter'),
        content: const Text('Are you sure you want to delete this meter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      final id = (meter['id'] ?? '').toString();
      _meters.removeWhere((m) => (m['id'] ?? '').toString() == id);
    });
  }

  void _saveAndClose() {
    Navigator.of(context).pop(
      _meters.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredMeters;

    return AppScaffold(
      title: widget.title,
      body: Column(
        children: [
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No meters captured'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = rows[i];
                      return ListTile(
                        title: Text(_displayTitle(m)),
                        subtitle: _displaySubtitle(m) == null
                            ? null
                            : Text(_displaySubtitle(m)!),
                        onTap: () => _addOrEdit(existing: m),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(m),
                        ),
                      );
                    },
                  ),
          ),
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
                      child: ElevatedButton.icon(
                        onPressed: () => _addOrEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveAndClose,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                        ),
                        child: const Text('Save'),
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

class WebHeatMeterEditorScreen extends StatefulWidget {
  const WebHeatMeterEditorScreen({
    super.key,
    required this.baseMeterType,
    this.existing,
  });

  final String baseMeterType;
  final Map<String, dynamic>? existing;

  @override
  State<WebHeatMeterEditorScreen> createState() =>
      _WebHeatMeterEditorScreenState();
}

class _WebHeatMeterEditorScreenState extends State<WebHeatMeterEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _assetMakeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _assetModelFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();

  late final TextEditingController _assetMakeController = TextEditingController(
    text: (widget.existing?['make'] ?? '').toString(),
  );
  late final TextEditingController _assetModelController =
      TextEditingController(text: (widget.existing?['model'] ?? '').toString());
  late final TextEditingController _locationController = TextEditingController(
    text: (widget.existing?['location'] ?? '').toString(),
  );
  late final TextEditingController _serialNumberController =
      TextEditingController(
        text: (widget.existing?['serialNumber'] ?? '').toString(),
      );
  late final TextEditingController _meterReadingController =
      TextEditingController(
        text: (widget.existing?['reading'] ?? '').toString(),
      );
  late final TextEditingController _blockNameController = TextEditingController(
    text: _tryReadBracketSuffix(
      (widget.existing?['meterType'] ?? '').toString(),
    ),
  );

  String? _selectedAge;
  String? _operational;

  @override
  void initState() {
    super.initState();

    _selectedAge = _normalizeAgeBand(
      (widget.existing?['ageRange'] ?? '').toString(),
    );
    if (_selectedAge != null && _selectedAge!.trim().isEmpty) {
      _selectedAge = null;
    }

    final op = (widget.existing?['operational'] ?? '').toString().trim();
    _operational = op.isEmpty ? null : op;
  }

  static String? _tryReadBracketSuffix(String meterType) {
    final trimmed = meterType.trim();
    final start = trimmed.indexOf('(');
    final end = trimmed.lastIndexOf(')');
    if (start < 0 || end <= start) return '';
    return trimmed.substring(start + 1, end);
  }

  String _finalMeterType() {
    final base = widget.baseMeterType;
    if ((base == 'Block Level Meter' || base == 'Bulk Heat Meter') &&
        _blockNameController.text.trim().isNotEmpty) {
      return '$base (${_blockNameController.text.trim()})';
    }
    return base;
  }

  String? _normalizeAgeBand(String? value) {
    switch ((value ?? '').trim()) {
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
      case '20+ years':
      case '10+':
        return '10 plus years';
      default:
        return value;
    }
  }

  Map<String, String> _getAssetFilterContext() {
    return {'asset_type': widget.baseMeterType};
  }

  String _toCamelCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _toSmartCamelCase(String text) {
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

  Future<void> _saveAndClose() async {
    if (!_formKey.currentState!.validate()) return;

    await _assetMakeFieldKey.currentState?.saveSuggestion();
    await _assetModelFieldKey.currentState?.saveSuggestion();
    await _locationFieldKey.currentState?.saveSuggestion();

    final now = DateTime.now().toUtc();

    final existing = widget.existing;
    final id = (existing?['id'] ?? '').toString().trim().isNotEmpty
        ? (existing!['id']).toString()
        : const Uuid().v4();

    final existingCreatedAt = (existing?['createdAt'] ?? '').toString().trim();

    final out = <String, dynamic>{
      'id': id,
      'meterType': _finalMeterType(),
      'make': _toCamelCase(_assetMakeController.text.trim()),
      'model': _toSmartCamelCase(_assetModelController.text.trim()),
      'location': _toCamelCase(_locationController.text.trim()),
      'ageRange': _selectedAge,
      'serialNumber': _serialNumberController.text.trim().isEmpty
          ? null
          : _serialNumberController.text.trim(),
      'operational': _operational,
      'reading': _meterReadingController.text.trim().isEmpty
          ? null
          : _meterReadingController.text.trim(),
      // Web editor does not currently manage photos; preserve existing where possible.
      'imagePaths': existing?['imagePaths'] is List
          ? List<dynamic>.from(existing!['imagePaths'] as List)
          : <dynamic>[],
      'relatedAssetType': existing?['relatedAssetType'],
      'relatedAssetId': existing?['relatedAssetId'],
      'createdAt': existingCreatedAt.isNotEmpty
          ? existingCreatedAt
          : now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    if (!mounted) return;
    Navigator.of(context).pop(out);
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AppScaffold(
      title: isEditing
          ? 'Edit ${widget.baseMeterType}'
          : 'Add ${widget.baseMeterType}',
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
                  AppTextField(
                    label: 'Meter Type',
                    controller: TextEditingController(
                      text: widget.baseMeterType,
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 24),
                  if (widget.baseMeterType == 'Block Level Meter' ||
                      widget.baseMeterType == 'Bulk Heat Meter') ...[
                    AppTextField(
                      label: widget.baseMeterType == 'Block Level Meter'
                          ? 'What block does it serve?'
                          : 'What does this meter serve?',
                      controller: _blockNameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return widget.baseMeterType == 'Block Level Meter'
                              ? 'Please enter the block name'
                              : 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
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
                    builder: (field) {
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
                  if (_operational == 'YES') ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Meter Index Reading',
                      controller: _meterReadingController,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: _saveAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Save'),
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
