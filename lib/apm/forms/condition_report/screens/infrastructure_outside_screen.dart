import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';

class InfrastructureOutsideScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;

  const InfrastructureOutsideScreen({
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
  State<InfrastructureOutsideScreen> createState() =>
      _InfrastructureOutsideScreenState();
}

class _InfrastructureOutsideScreenState
    extends State<InfrastructureOutsideScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _io1Supported;
  String? _io2Identified;
  String? _io3VisuallySound;
  String? _io4Sleeved;

  Map<String, dynamic>? _io1Observation;
  Map<String, dynamic>? _io2Observation;
  Map<String, dynamic>? _io3Observation;
  Map<String, dynamic>? _io4Observation;

  @override
  void initState() {
    super.initState();
    _io1Supported = widget.formData['io1Supported'];
    _io2Identified = widget.formData['io2Identified'];
    _io3VisuallySound = widget.formData['io3VisuallySound'];
    _io4Sleeved = widget.formData['io4Sleeved'];

    _io1Observation = widget.formData['io1Observation'];
    _io2Observation = widget.formData['io2Observation'];
    _io3Observation = widget.formData['io3Observation'];
    _io4Observation = widget.formData['io4Observation'];
  }

  void _saveAndContinue() {
    // Validate all questions are answered
    final unansweredQuestions = <String>[];

    if (_io1Supported == null) unansweredQuestions.add('Adequately supported?');
    if (_io2Identified == null) unansweredQuestions.add('Suitably identified?');
    if (_io3VisuallySound == null) unansweredQuestions.add('Visually sound?');
    if (_io4Sleeved == null) {
      unansweredQuestions.add('Sleeved when passing through walls and floors?');
    }

    if (unansweredQuestions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please answer all questions before continuing'),
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

    if (_formKey.currentState?.validate() ?? false) {
      widget.onDataChanged('io1Supported', _io1Supported);
      widget.onDataChanged('io2Identified', _io2Identified);
      widget.onDataChanged('io3VisuallySound', _io3VisuallySound);
      widget.onDataChanged('io4Sleeved', _io4Sleeved);

      widget.onDataChanged('io1Observation', _io1Observation);
      widget.onDataChanged('io2Observation', _io2Observation);
      widget.onDataChanged('io3Observation', _io3Observation);
      widget.onDataChanged('io4Observation', _io4Observation);

      // Move to next screen
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
                      Text(
                        'Is all visible gas installation pipework outside of the plant room:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      AppQuestionBlock(
                        questionText: 'Adequately supported?',
                        questionReference: 'io1',
                        sectionName: 'Infrastructure Outside',
                        selectedAnswer: _io1Supported,
                        onAnswerChanged: (value) =>
                            setState(() => _io1Supported = value),
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call('io1') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                      AppQuestionBlock(
                        questionText: 'Suitably identified?',
                        questionReference: 'io2',
                        sectionName: 'Infrastructure Outside',
                        selectedAnswer: _io2Identified,
                        onAnswerChanged: (value) =>
                            setState(() => _io2Identified = value),
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call('io2') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                      AppQuestionBlock(
                        questionText: 'Visually sound?',
                        questionReference: 'io3',
                        sectionName: 'Infrastructure Outside',
                        selectedAnswer: _io3VisuallySound,
                        onAnswerChanged: (value) =>
                            setState(() => _io3VisuallySound = value),
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call('io3') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                      AppQuestionBlock(
                        questionText:
                            'Sleeved when passing through walls and floors?',
                        questionReference: 'io4',
                        sectionName: 'Infrastructure Outside',
                        selectedAnswer: _io4Sleeved,
                        onAnswerChanged: (value) =>
                            setState(() => _io4Sleeved = value),
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call('io4') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Space for fixed buttons
              ],
            ),
          ),
        ),
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
