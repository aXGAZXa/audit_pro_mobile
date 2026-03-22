import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:image_picker/image_picker.dart';

class AssetsContinuedScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;

  const AssetsContinuedScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
    this.onObservationsChanged,
    this.hasObservations,
  });

  @override
  State<AssetsContinuedScreen> createState() => _AssetsContinuedScreenState();
}

class _AssetsContinuedScreenState extends State<AssetsContinuedScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _heatMeters;
  String? _heatMetersOperational;
  List<XFile> _applianceFlueSystems = [];

  @override
  void initState() {
    super.initState();
    _heatMeters = widget.formData['heatMeters'];
    _heatMetersOperational = widget.formData['heatMetersOperational'];

    // Load existing images if any
    final existingImages = widget.formData['applianceFlueSystems'];
    if (existingImages != null && existingImages is List) {
      _applianceFlueSystems = existingImages
          .map((path) => XFile(path.toString()))
          .toList()
          .cast<XFile>();
    }
  }

  void _saveAndContinue() {
    // Validate only VISIBLE questions
    List<String> missingAnswers = [];

    // Heat meters question is always required
    if (_heatMeters == null) {
      missingAnswers.add('Are bulk heat meters provided?');
    }

    // Heat meters operational question is only required if first question is YES
    if (_heatMeters == 'YES' && _heatMetersOperational == null) {
      missingAnswers.add('Are Bulk heat meters visually operational?');
    }

    if (missingAnswers.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Answers'),
          content: Text(
            'Please answer the following question(s):\n\n${missingAnswers.join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    widget.onDataChanged('heatMeters', _heatMeters);
    widget.onDataChanged('heatMetersOperational', _heatMetersOperational);
    widget.onDataChanged(
      'applianceFlueSystems',
      _applianceFlueSystems.map((img) => img.path).toList(),
    );

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appliance Flue Systems (Image Capture)
                      AppMediaBlock(
                        questionText:
                            'Document all VISIBLE internal and external flue systems and terminations.',
                        questionReference: 'applianceFlueSystems',
                        sectionName: 'Assets Continued',
                        images: _applianceFlueSystems,
                        onImagesChanged: (images) {
                          setState(() => _applianceFlueSystems = images);
                        },
                        maxImages: 999,
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call(
                              'applianceFlueSystems',
                            ) ??
                            false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                      const SizedBox(height: 24),

                      // Heat Meters
                      AppQuestionBlock(
                        questionText: 'Are bulk heat meters fitted?',
                        questionReference: 'heatMeters',
                        selectedAnswer: _heatMeters,
                        onAnswerChanged: (value) {
                          setState(() {
                            _heatMeters = value;
                            // Reset operational answer if not YES
                            if (value != 'YES') {
                              _heatMetersOperational = null;
                            }
                          });
                        },
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call('heatMeters') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),

                      // Conditional follow-up question
                      if (_heatMeters == 'YES') ...[
                        const SizedBox(height: 24),
                        AppQuestionBlock(
                          questionText:
                              'Are Bulk heat meters visually operational?',
                          questionReference: 'heatMetersOperational',
                          selectedAnswer: _heatMetersOperational,
                          onAnswerChanged: (value) =>
                              setState(() => _heatMetersOperational = value),
                          formId: widget.formId,
                          hasObservations:
                              widget.hasObservations?.call(
                                'heatMetersOperational',
                              ) ??
                              false,
                          onObservationsChanged: widget.onObservationsChanged,
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
