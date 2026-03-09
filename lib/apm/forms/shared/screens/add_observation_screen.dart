import 'package:audit_pro_mobile/apm/components/app_autocomplete_field.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audit_pro_mobile/apm/services/platform/image_persistence.dart';

class AddObservationScreen extends StatefulWidget {
  final String? title;
  final Function(String notes, List<XFile> images)? onSave;

  const AddObservationScreen({super.key, this.title, this.onSave});

  @override
  State<AddObservationScreen> createState() => _AddObservationScreenState();
}

class _AddObservationScreenState extends State<AddObservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _notesController = TextEditingController();
  final List<XFile?> _images = [null];
  bool _isInitialized = false;
  bool _isUnsafe = false;
  String? _unsafeClassification;
  String? _questionReference;
  String? _assetType;
  String? _sectionName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;
    _isInitialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _questionReference = args?['questionReference'] as String?;
    _assetType = args?['assetType'] as String?;
    _sectionName = args?['sectionName'] as String?;

    if (args == null || args['existingObservation'] == null) return;
    final existingObs = args['existingObservation'] as Map<String, dynamic>;

    final notes = existingObs['notes'];
    if (notes is String) {
      _notesController.text = notes;
    }

    final unsafe = existingObs['is_unsafe'];
    if (unsafe != null) {
      _isUnsafe = unsafe == 1 || unsafe == true;
    }

    final classification = existingObs['unsafe_classification'];
    if (classification is String) {
      _unsafeClassification = classification;
    }

    final existingImages = existingObs['images'];
    if (existingImages is List) {
      _images
        ..clear()
        ..addAll(existingImages.whereType<XFile>());

      if (_images.isEmpty || _images.last != null) {
        _images.add(null);
      }
    }
  }

  Map<String, String>? _getObservationNotesFilterContext() {
    final hasAssetType = _assetType != null && _assetType!.trim().isNotEmpty;
    if (hasAssetType) {
      return {'observation_scope': 'asset', 'asset_type': _assetType!.trim()};
    }

    final hasQuestionRef =
        _questionReference != null && _questionReference!.trim().isNotEmpty;
    if (hasQuestionRef) {
      return {
        'observation_scope': 'question',
        'question_reference': _questionReference!.trim(),
      };
    }

    final hasSectionName =
        _sectionName != null && _sectionName!.trim().isNotEmpty;
    if (hasSectionName) {
      return {
        'observation_scope': 'section',
        'section_name': _sectionName!.trim(),
      };
    }

    return null;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _handleImageChanged(int index, XFile? image) {
    setState(() {
      _images[index] = image;

      if (index == _images.length - 1 && image != null) {
        _images.add(null);
      }

      while (_images.length > 1 &&
          _images.last == null &&
          _images[_images.length - 2] == null) {
        _images.removeLast();
      }
    });
  }

  Future<void> _saveObservation() async {
    if (!_formKey.currentState!.validate()) return;

    await _notesFieldKey.currentState?.saveSuggestion();
    if (!mounted) return;

    final notes = _notesController.text;
    final capturedImages = _images
        .where((img) => img != null)
        .cast<XFile>()
        .toList();

    final imagesToSave = capturedImages.isEmpty
        ? capturedImages
        : (await persistPickedImagePaths(
            capturedImages,
            prefix: 'obs',
          )).map(XFile.new).toList(growable: false);

    if (widget.onSave != null) {
      widget.onSave!(notes, imagesToSave);
    }

    if (!mounted) return;
    Navigator.pop(context, {
      'notes': notes,
      'images': imagesToSave,
      'is_unsafe': _isUnsafe,
      'unsafe_classification': _unsafeClassification,
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesFilterContext = _getObservationNotesFilterContext();

    return AppScaffold(
      title: widget.title ?? 'Add Observation',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gas Unsafe',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isUnsafe,
                            onChanged: (value) {
                              setState(() {
                                _isUnsafe = value;
                                if (!value) _unsafeClassification = null;
                              });
                            },
                            activeThumbColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.8),
                            activeTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            inactiveThumbColor: Colors.grey[400],
                            inactiveTrackColor: Colors.grey[200],
                            trackOutlineColor:
                                WidgetStateProperty.resolveWith<Color?>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.transparent;
                                  }
                                  return Colors.grey[300];
                                }),
                          ),
                        ],
                      ),
                      if (_isUnsafe) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Classification Level',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            ChoiceChip(
                              label: const SizedBox(
                                width: double.infinity,
                                child: Center(child: Text('At Risk')),
                              ),
                              selected:
                                  _unsafeClassification == 'AR' ||
                                  _unsafeClassification == 'At Risk',
                              onSelected: (_) =>
                                  setState(() => _unsafeClassification = 'AR'),
                            ),
                            const SizedBox(height: 12),
                            ChoiceChip(
                              label: const SizedBox(
                                width: double.infinity,
                                child: Center(
                                  child: Text('Immediately Dangerous'),
                                ),
                              ),
                              selected:
                                  _unsafeClassification == 'ID' ||
                                  _unsafeClassification ==
                                      'Immediately Dangerous',
                              onSelected: (_) =>
                                  setState(() => _unsafeClassification = 'ID'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      AppAutocompleteField(
                        key: _notesFieldKey,
                        controller: _notesController,
                        label: 'Observation Notes',
                        hint: 'Describe what you observed',
                        fieldName: 'observation_notes',
                        maxLines: 5,
                        minCharsForSuggestions: 5,
                        filterContext: notesFilterContext == null
                            ? null
                            : () => notesFilterContext,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Notes are required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Images',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_images.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppImageCapture(
                            label: 'Photo ${index + 1}',
                            hint: index == 0
                                ? 'Capture your first photo'
                                : 'Add another photo (optional)',
                            image: _images[index],
                            onImageChanged: (newImage) =>
                                _handleImageChanged(index, newImage),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveObservation,
                child: const Text('Save Observation'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
