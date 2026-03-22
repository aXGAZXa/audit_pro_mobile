import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';

class PlantRoomElectricalScreen extends StatefulWidget {
  const PlantRoomElectricalScreen({super.key});

  @override
  State<PlantRoomElectricalScreen> createState() =>
      _PlantRoomElectricalScreenState();
}

class _PlantRoomElectricalScreenState extends State<PlantRoomElectricalScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _formId;
  int? _plantRoomId;

  String? _pe1SufficientlyLit;
  String? _pe2LightingSuitable;
  String? _pe3HeatingControls;
  String? _pe4AutoManualMode;
  String? _pe5Insulation;
  String? _pe6ElectricalFittings;
  String? _pe7CablingContained;
  String? _pe9EmergencyControls;
  String? _pe10SystemFitted;
  String? _pe11LeakSensors;

  void _setAllAnswersToYes() {
    setState(() {
      _pe1SufficientlyLit = 'YES';
      _pe2LightingSuitable = 'YES';
      _pe3HeatingControls = 'YES';
      _pe4AutoManualMode = 'YES';
      _pe5Insulation = 'YES';
      _pe6ElectricalFittings = 'YES';
      _pe7CablingContained = 'YES';
      _pe9EmergencyControls = 'YES';
      _pe10SystemFitted = 'YES';
      _pe11LeakSensors = 'YES';
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
        _pe1SufficientlyLit = responses['pe1SufficientlyLit'];
        _pe2LightingSuitable = responses['pe2LightingSuitable'];
        _pe3HeatingControls = responses['pe3HeatingControls'];
        _pe4AutoManualMode = responses['pe4AutoManualMode'];
        _pe5Insulation = responses['pe5Insulation'];
        _pe6ElectricalFittings = responses['pe6ElectricalFittings'];
        _pe7CablingContained = responses['pe7CablingContained'];
        _pe9EmergencyControls = responses['pe9EmergencyControls'];
        _pe10SystemFitted = responses['pe10SystemFitted'];
        _pe11LeakSensors = responses['pe11LeakSensors'];
      });
    }
  }

  Future<void> _saveAndReturn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_plantRoomId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plant room ID is required')),
        );
      }
      return;
    }

    final missingAnswers = <String>[];
    if (_pe1SufficientlyLit == null) missingAnswers.add('Sufficiently lit?');
    if (_pe2LightingSuitable == null) missingAnswers.add('Lighting suitable?');
    if (_pe3HeatingControls == null) missingAnswers.add('Heating controls?');
    if (_pe4AutoManualMode == null) missingAnswers.add('Auto/manual mode?');
    if (_pe5Insulation == null) missingAnswers.add('Insulation?');
    if (_pe6ElectricalFittings == null) {
      missingAnswers.add('Electrical fittings?');
    }
    if (_pe7CablingContained == null) missingAnswers.add('Cabling contained?');
    if (_pe9EmergencyControls == null) {
      missingAnswers.add('Emergency controls?');
    }
    if (_pe10SystemFitted == null) missingAnswers.add('System fitted?');
    if (_pe11LeakSensors == null) missingAnswers.add('Leak sensors?');

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
        'pe1SufficientlyLit': _pe1SufficientlyLit,
        'pe2LightingSuitable': _pe2LightingSuitable,
        'pe3HeatingControls': _pe3HeatingControls,
        'pe4AutoManualMode': _pe4AutoManualMode,
        'pe5Insulation': _pe5Insulation,
        'pe6ElectricalFittings': _pe6ElectricalFittings,
        'pe7CablingContained': _pe7CablingContained,
        'pe9EmergencyControls': _pe9EmergencyControls,
        'pe10SystemFitted': _pe10SystemFitted,
        'pe11LeakSensors': _pe11LeakSensors,
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Electrical',
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
                          'Electrical',
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
                          questionText: 'Is plant room sufficiently lit?',
                          questionReference: 'pe1',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe1SufficientlyLit,
                          onAnswerChanged: (value) =>
                              setState(() => _pe1SufficientlyLit = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is plant room lighting suitable for use?',
                          questionReference: 'pe2',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe2LightingSuitable,
                          onAnswerChanged: (value) =>
                              setState(() => _pe2LightingSuitable = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Do heating controls appear visually operational?',
                          questionReference: 'pe3',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe3HeatingControls,
                          onAnswerChanged: (value) =>
                              setState(() => _pe3HeatingControls = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is all plant operation in "Auto/Managed Mode" & not the BMS (if present)?',
                          questionReference: 'pe4',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe4AutoManualMode,
                          onAnswerChanged: (value) =>
                              setState(() => _pe4AutoManualMode = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is an insulation mat provided at the base of the BMS panel (if present)?',
                          questionReference: 'pe5',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe5Insulation,
                          onAnswerChanged: (value) =>
                              setState(() => _pe5Insulation = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Do any electrical fittings appear damaged?',
                          questionReference: 'pe6',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe6ElectricalFittings,
                          onAnswerChanged: (value) =>
                              setState(() => _pe6ElectricalFittings = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is all cabling appropriately contained/supported?',
                          questionReference: 'pe7',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe7CablingContained,
                          onAnswerChanged: (value) =>
                              setState(() => _pe7CablingContained = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Do any REQUIRED emergency controls appear VISUALLY satisfactory?',
                          questionReference: 'pe9',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe9EmergencyControls,
                          onAnswerChanged: (value) =>
                              setState(() => _pe9EmergencyControls = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is the system fitted with CO/Gas Leak detection?',
                          questionReference: 'pe10',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe10SystemFitted,
                          onAnswerChanged: (value) =>
                              setState(() => _pe10SystemFitted = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Do any installed CO/Gas Leak sensors appear VISUALLY operational?',
                          questionReference: 'pe11',
                          sectionName: 'Plant Room - Electrical',
                          selectedAnswer: _pe11LeakSensors,
                          onAnswerChanged: (value) =>
                              setState(() => _pe11LeakSensors = value),
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
