import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:image_picker/image_picker.dart';

class CommunalHeatingSystemScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;
  final FormRepository? repo;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;

  const CommunalHeatingSystemScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
    this.repo,
    this.onObservationsChanged,
    this.hasObservations,
  });

  @override
  State<CommunalHeatingSystemScreen> createState() =>
      _CommunalHeatingSystemScreenState();
}

class _CommunalHeatingSystemScreenState
    extends State<CommunalHeatingSystemScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isNotApplicable = false;
  List<XFile> _communalRadiatorImages = [];
  List<XFile> _communalPipeworkImages = [];
  String? _systemCondition;

  @override
  void initState() {
    super.initState();
    _isNotApplicable = widget.formData['communalHeatingNA'] == true;
    _systemCondition = widget.formData['communalHeatingSystemCondition'];

    // Load existing images
    final radiatorImages = widget.formData['communalRadiatorImages'];
    if (radiatorImages != null && radiatorImages is List) {
      _communalRadiatorImages = radiatorImages
          .map((path) => XFile(path.toString()))
          .toList()
          .cast<XFile>();
    }

    final pipeworkImages = widget.formData['communalPipeworkImages'];
    if (pipeworkImages != null && pipeworkImages is List) {
      _communalPipeworkImages = pipeworkImages
          .map((path) => XFile(path.toString()))
          .toList()
          .cast<XFile>();
    }
  }

  void _saveAndContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      // If access is granted, validate required fields
      if (!_isNotApplicable) {
        // Check for at least one radiator image
        if (_communalRadiatorImages.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Missing Images'),
              content: const Text(
                'Please add at least one image for Typical Communal Radiator.',
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

        // Check for at least one pipework image
        if (_communalPipeworkImages.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Missing Images'),
              content: const Text(
                'Please add at least one image for Typical Communal Heating Pipework.',
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

        // Check for RAG rating selection
        if (_systemCondition == null || _systemCondition!.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Missing Condition Rating'),
              content: const Text(
                'Please select a condition rating (Good, Fair, or Poor) for the general visual heating system condition.',
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
      }

      widget.onDataChanged('communalHeatingNA', _isNotApplicable);
      widget.onDataChanged(
        'communalRadiatorImages',
        _communalRadiatorImages.map((img) => img.path).toList(),
      );
      widget.onDataChanged(
        'communalPipeworkImages',
        _communalPipeworkImages.map((img) => img.path).toList(),
      );
      widget.onDataChanged('communalHeatingSystemCondition', _systemCondition);

      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Access to Communal Area Question with Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Access to Communal Area?',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Switch(
                            value: !_isNotApplicable,
                            onChanged: (value) {
                              setState(() {
                                _isNotApplicable = !value;
                                if (_isNotApplicable) {
                                  // Clear data when access is denied
                                  _communalRadiatorImages = [];
                                  _communalPipeworkImages = [];
                                  _systemCondition = null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Show fields only if access is granted
                      if (!_isNotApplicable) ...[
                        // Typical Communal Radiator
                        AppMediaBlock(
                          questionText: 'Typical Communal Radiator',
                          questionReference: 'communalRadiatorImages',
                          sectionName: 'Communal Heating System',
                          images: _communalRadiatorImages,
                          onImagesChanged: (images) {
                            setState(() => _communalRadiatorImages = images);
                          },
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call(
                                'communalRadiatorImages',
                              ) ??
                              false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        const SizedBox(height: 24),

                        // Typical Communal Heating Pipework
                        AppMediaBlock(
                          questionText: 'Typical Communal Heating Pipework',
                          questionReference: 'communalPipeworkImages',
                          sectionName: 'Communal Heating System',
                          images: _communalPipeworkImages,
                          onImagesChanged: (images) {
                            setState(() => _communalPipeworkImages = images);
                          },
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call(
                                'communalPipeworkImages',
                              ) ??
                              false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        const SizedBox(height: 24),

                        // General visual heating system condition
                        Text(
                          'General visual heating system condition',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _systemCondition,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          hint: const Text('Select condition'),
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
                            setState(() => _systemCondition = value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navigation Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                Expanded(
                  child: AppButton(text: 'Back', onPressed: widget.onBack),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(text: 'Next', onPressed: _saveAndContinue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
