import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';

class PlantRoomGasPipeworkScreen extends StatefulWidget {
  const PlantRoomGasPipeworkScreen({super.key});

  @override
  State<PlantRoomGasPipeworkScreen> createState() =>
      _PlantRoomGasPipeworkScreenState();
}

class _PlantRoomGasPipeworkScreenState
    extends State<PlantRoomGasPipeworkScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _formId;
  int? _plantRoomId;

  String? _pi1Supported;
  String? _pi2Identified;
  String? _pi3Satisfactory;
  String? _pi4Sleeved;
  String? _pi5IsolationValves;
  String? _pi6EarthBonding;
  String? _pi7NoSmell;

  void _setAllAnswersToYes() {
    setState(() {
      _pi1Supported = 'YES';
      _pi2Identified = 'YES';
      _pi3Satisfactory = 'YES';
      _pi4Sleeved = 'YES';
      _pi5IsolationValves = 'YES';
      _pi6EarthBonding = 'YES';
      _pi7NoSmell = 'YES';
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
        _pi1Supported = responses['pi1Supported'];
        _pi2Identified = responses['pi2Identified'];
        _pi3Satisfactory = responses['pi3Satisfactory'];
        _pi4Sleeved = responses['pi4Sleeved'];
        _pi5IsolationValves = responses['pi5IsolationValves'];
        _pi6EarthBonding = responses['pi6EarthBonding'];
        _pi7NoSmell = responses['pi7NoSmell'];
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
    if (_pi1Supported == null) missingAnswers.add('Adequately supported?');
    if (_pi2Identified == null) missingAnswers.add('Suitably identified?');
    if (_pi3Satisfactory == null) missingAnswers.add('Visually satisfactory?');
    if (_pi4Sleeved == null) missingAnswers.add('Sleeved?');
    if (_pi5IsolationValves == null) missingAnswers.add('Isolation valves?');
    if (_pi6EarthBonding == null) missingAnswers.add('Earth bonding?');
    if (_pi7NoSmell == null) missingAnswers.add('No smell of gas?');

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

    await DatabaseHelper.instance.savePlantRoomResponses(
      plantRoomId: _plantRoomId!,
      responses: {
        'pi1Supported': _pi1Supported,
        'pi2Identified': _pi2Identified,
        'pi3Satisfactory': _pi3Satisfactory,
        'pi4Sleeved': _pi4Sleeved,
        'pi5IsolationValves': _pi5IsolationValves,
        'pi6EarthBonding': _pi6EarthBonding,
        'pi7NoSmell': _pi7NoSmell,
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gas Pipework',
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
                          'Is all visible gas installation pipework inside the plant room:',
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
                          questionText: 'Adequately supported?',
                          questionReference: 'pi1',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi1Supported,
                          onAnswerChanged: (value) =>
                              setState(() => _pi1Supported = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Suitably identified?',
                          questionReference: 'pi2',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi2Identified,
                          onAnswerChanged: (value) =>
                              setState(() => _pi2Identified = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Visually satisfactory?',
                          questionReference: 'pi3',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi3Satisfactory,
                          onAnswerChanged: (value) =>
                              setState(() => _pi3Satisfactory = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Sleeved when passing through walls and floors?',
                          questionReference: 'pi4',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi4Sleeved,
                          onAnswerChanged: (value) =>
                              setState(() => _pi4Sleeved = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Are suitable isolation valves, purging and testing points provided?',
                          questionReference: 'pi5',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi5IsolationValves,
                          onAnswerChanged: (value) =>
                              setState(() => _pi5IsolationValves = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Where required is suitable local earth bonding provided?',
                          questionReference: 'pi6',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi6EarthBonding,
                          onAnswerChanged: (value) =>
                              setState(() => _pi6EarthBonding = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'No smell of gas?',
                          questionReference: 'pi7',
                          sectionName: 'Plant Room - Gas Pipework',
                          selectedAnswer: _pi7NoSmell,
                          onAnswerChanged: (value) =>
                              setState(() => _pi7NoSmell = value),
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
