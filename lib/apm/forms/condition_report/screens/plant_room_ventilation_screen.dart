import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';

class PlantRoomVentilationScreen extends StatefulWidget {
  const PlantRoomVentilationScreen({super.key});

  @override
  State<PlantRoomVentilationScreen> createState() =>
      _PlantRoomVentilationScreenState();
}

class _PlantRoomVentilationScreenState
    extends State<PlantRoomVentilationScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _formId;
  int? _plantRoomId;

  String? _v1Satisfactory;
  String? _v2Overheating;

  void _setAllAnswersToYes() {
    setState(() {
      _v1Satisfactory = 'YES';
      _v2Overheating = 'YES';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _formId = args['formId'] as int?;
      _plantRoomId = args['plantRoomId'] as int?;

      // Load existing responses
      if (_plantRoomId != null) {
        _loadResponses();
      }
    }
  }

  Future<void> _loadResponses() async {
    if (_plantRoomId == null) return;

    final responses = await DatabaseHelper.instance.getPlantRoomResponses(
      _plantRoomId!,
    );
    if (mounted) {
      setState(() {
        _v1Satisfactory = responses['v1Satisfactory'];
        _v2Overheating = responses['v2Overheating'];
      });
    }
  }

  Future<void> _saveAndReturn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_plantRoomId == null) {
      if (mounted) {
        ApmFeedback.error(context, 'Plant room ID is required');
      }
      return;
    }

    // Validate all questions answered
    final missingAnswers = <String>[];
    if (_v1Satisfactory == null) {
      missingAnswers.add('Is any provided ventilation visually satisfactory?');
    }
    if (_v2Overheating == null) {
      missingAnswers.add('Does the plant room appear to be overheating');
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

    // Save responses
    await DatabaseHelper.instance.savePlantRoomResponses(
      plantRoomId: _plantRoomId!,
      responses: {
        'v1Satisfactory': _v1Satisfactory,
        'v2Overheating': _v2Overheating,
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ventilation',
      body: Column(
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
                          'Ventilation',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _setAllAnswersToYes,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Yes to all'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppQuestionBlock(
                          questionText:
                              'Is any provided ventilation visually satisfactory?',
                          questionReference: 'v1',
                          sectionName: 'Plant Room - Ventilation',
                          selectedAnswer: _v1Satisfactory,
                          onAnswerChanged: (value) =>
                              setState(() => _v1Satisfactory = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Does the plant room appear to be overheating',
                          questionReference: 'v2',
                          sectionName: 'Plant Room - Ventilation',
                          selectedAnswer: _v2Overheating,
                          onAnswerChanged: (value) =>
                              setState(() => _v2Overheating = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
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
            child: ElevatedButton(
              onPressed: _saveAndReturn,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Save & Return'),
            ),
          ),
        ],
      ),
    );
  }
}
