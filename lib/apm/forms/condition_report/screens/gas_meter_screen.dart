import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';

class GasMeterScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;
  final FormRepository? repo;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;

  const GasMeterScreen({
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
  State<GasMeterScreen> createState() => _GasMeterScreenState();
}

class _GasMeterScreenState extends State<GasMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();

  String? _g1Accessible;
  String? _g2SuitableLocation;
  String? _g3CorrectlyInstalled;
  String? _g4Ventilated;
  String? _g5Secure;
  String? _g6Labelled;
  String? _g7IsolationValves;
  String? _g8EarthBonding;
  String? _g9LineDiagram;
  String? _g10NoGasSmell;

  @override
  void initState() {
    super.initState();
    // Load existing form data if any
    _locationController.text = widget.formData['gasMeterLocation'] ?? '';
    _g1Accessible = widget.formData['g1Accessible'];
    _g2SuitableLocation = widget.formData['g2SuitableLocation'];
    _g3CorrectlyInstalled = widget.formData['g3CorrectlyInstalled'];
    _g4Ventilated = widget.formData['g4Ventilated'];
    _g5Secure = widget.formData['g5Secure'];
    _g6Labelled = widget.formData['g6Labelled'];
    _g7IsolationValves = widget.formData['g7IsolationValves'];
    _g8EarthBonding = widget.formData['g8EarthBonding'];
    _g9LineDiagram = widget.formData['g9LineDiagram'];
    _g10NoGasSmell = widget.formData['g10NoGasSmell'];
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    // Validate that Accessible is answered
    if (_g1Accessible == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please answer the Accessible question'),
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

    // If accessible is YES, validate all other visible questions
    if (_g1Accessible == 'YES') {
      final unansweredQuestions = <String>[];

      if (_g2SuitableLocation == null) {
        unansweredQuestions.add('Fitted in a suitable location?');
      }
      if (_g3CorrectlyInstalled == null) {
        unansweredQuestions.add('Correctly installed?');
      }
      if (_g4Ventilated == null) {
        unansweredQuestions.add('Adequately ventilated?');
      }
      if (_g5Secure == null) unansweredQuestions.add('Secure?');
      if (_g6Labelled == null) unansweredQuestions.add('Correctly labelled?');
      if (_g7IsolationValves == null) {
        unansweredQuestions.add(
          'Fitted with correctly labelled isolation valves?',
        );
      }
      if (_g8EarthBonding == null) {
        unansweredQuestions.add(
          'Supplied with adequate equipotential earth bonding',
        );
      }
      if (_g9LineDiagram == null) {
        unansweredQuestions.add('Supplied with an up-to-date line diagram?');
      }
      if (_g10NoGasSmell == null) unansweredQuestions.add('No smell of gas?');

      if (unansweredQuestions.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Validation Required'),
            content: const Text(
              'Please answer all questions before continuing',
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

    if (_formKey.currentState!.validate()) {
      // Save all form data
      widget.onDataChanged('gasMeterLocation', _locationController.text);
      widget.onDataChanged('g1Accessible', _g1Accessible);
      widget.onDataChanged('g2SuitableLocation', _g2SuitableLocation);
      widget.onDataChanged('g3CorrectlyInstalled', _g3CorrectlyInstalled);
      widget.onDataChanged('g4Ventilated', _g4Ventilated);
      widget.onDataChanged('g5Secure', _g5Secure);
      widget.onDataChanged('g6Labelled', _g6Labelled);
      widget.onDataChanged('g7IsolationValves', _g7IsolationValves);
      widget.onDataChanged('g8EarthBonding', _g8EarthBonding);
      widget.onDataChanged('g9LineDiagram', _g9LineDiagram);
      widget.onDataChanged('g10NoGasSmell', _g10NoGasSmell);

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
                        'Is the Gas Meter:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      AppQuestionBlock(
                        questionText: 'Accessible?',
                        questionReference: 'g1',
                        sectionName: 'Gas Meter',
                        selectedAnswer: _g1Accessible,
                        onAnswerChanged: (value) {
                          setState(() {
                            _g1Accessible = value;
                            // Reset other answers if not accessible
                            if (value != 'YES') {
                              _g2SuitableLocation = null;
                              _g3CorrectlyInstalled = null;
                              _g4Ventilated = null;
                              _g5Secure = null;
                              _g6Labelled = null;
                              _g7IsolationValves = null;
                              _g8EarthBonding = null;
                              _g9LineDiagram = null;
                              _g10NoGasSmell = null;
                            }
                          });
                        },
                        formId: widget.formId,
                        repo: widget.repo,
                        hasObservations:
                            widget.hasObservations?.call('g1') ?? false,
                        onObservationsChanged: widget.onObservationsChanged,
                      ),
                      if (_g1Accessible == 'YES') ...[
                        AppQuestionBlock(
                          questionText: 'Fitted in a suitable location?',
                          questionReference: 'g2',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g2SuitableLocation,
                          onAnswerChanged: (value) =>
                              setState(() => _g2SuitableLocation = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g2') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText: 'Correctly installed?',
                          questionReference: 'g3',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g3CorrectlyInstalled,
                          onAnswerChanged: (value) =>
                              setState(() => _g3CorrectlyInstalled = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g3') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText: 'Adequately ventilated?',
                          questionReference: 'g4',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g4Ventilated,
                          onAnswerChanged: (value) =>
                              setState(() => _g4Ventilated = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g4') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText: 'Secure?',
                          questionReference: 'g5',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g5Secure,
                          onAnswerChanged: (value) =>
                              setState(() => _g5Secure = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g5') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText: 'Correctly labelled?',
                          questionReference: 'g6',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g6Labelled,
                          onAnswerChanged: (value) =>
                              setState(() => _g6Labelled = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g6') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Fitted with correctly labelled isolation valves?',
                          questionReference: 'g7',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g7IsolationValves,
                          onAnswerChanged: (value) =>
                              setState(() => _g7IsolationValves = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g7') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Supplied with adequate equipotential earth bonding',
                          questionReference: 'g8',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g8EarthBonding,
                          onAnswerChanged: (value) =>
                              setState(() => _g8EarthBonding = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g8') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Supplied with an up-to-date line diagram?',
                          questionReference: 'g9',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g9LineDiagram,
                          onAnswerChanged: (value) =>
                              setState(() => _g9LineDiagram = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g9') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                        AppQuestionBlock(
                          questionText: 'No smell of gas?',
                          questionReference: 'g10',
                          sectionName: 'Gas Meter',
                          selectedAnswer: _g10NoGasSmell,
                          onAnswerChanged: (value) =>
                              setState(() => _g10NoGasSmell = value),
                          formId: widget.formId,
                          repo: widget.repo,
                          hasObservations:
                              widget.hasObservations?.call('g10') ?? false,
                          onObservationsChanged: widget.onObservationsChanged,
                        ),
                      ],
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
