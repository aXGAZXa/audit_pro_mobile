import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';

class PlantRoomHydraulicsScreen extends StatefulWidget {
  const PlantRoomHydraulicsScreen({super.key});

  @override
  State<PlantRoomHydraulicsScreen> createState() =>
      _PlantRoomHydraulicsScreenState();
}

class _PlantRoomHydraulicsScreenState extends State<PlantRoomHydraulicsScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _formId;
  int? _plantRoomId;
  FormRepository? _repo;

  String? _ph1FreeOfLeaks;
  String? _ph2Corrosion;
  String? _ph3Insulated;
  String? _ph4Supported;
  String? _ph5Overpressure;
  String? _ph6WaterValves;
  String? _ph7VisuallySatisfactory;

  void _setAllAnswersToYes() {
    setState(() {
      _ph1FreeOfLeaks = 'YES';
      _ph2Corrosion = 'YES';
      _ph3Insulated = 'YES';
      _ph4Supported = 'YES';
      _ph5Overpressure = 'YES';
      _ph6WaterValves = 'YES';
      _ph7VisuallySatisfactory = 'YES';
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
      _repo = args['repo'] as FormRepository?;

      if (_plantRoomId != null) {
        _loadResponses();
      }
    }
  }

  Future<void> _loadResponses() async {
    if (_plantRoomId == null) return;

    final item = await _repo?.getCollectionItem('plantRooms', _plantRoomId!);
    final responses = (item?['responses'] is Map)
        ? Map<String, dynamic>.from(item!['responses'] as Map)
        : <String, dynamic>{};
    if (mounted) {
      setState(() {
        _ph1FreeOfLeaks = responses['ph1FreeOfLeaks'];
        _ph2Corrosion = responses['ph2Corrosion'];
        _ph3Insulated = responses['ph3Insulated'];
        _ph4Supported = responses['ph4Supported'];
        _ph5Overpressure = responses['ph5Overpressure'];
        _ph6WaterValves = responses['ph6WaterValves'];
        _ph7VisuallySatisfactory = responses['ph7VisuallySatisfactory'];
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

    final missingAnswers = <String>[];
    if (_ph1FreeOfLeaks == null) missingAnswers.add('Free of leaks?');
    if (_ph2Corrosion == null) missingAnswers.add('Corrosion?');
    if (_ph3Insulated == null) missingAnswers.add('Insulated?');
    if (_ph4Supported == null) missingAnswers.add('Supported?');
    if (_ph5Overpressure == null) missingAnswers.add('Overpressure?');
    if (_ph6WaterValves == null) missingAnswers.add('Water valves?');
    if (_ph7VisuallySatisfactory == null) {
      missingAnswers.add('Visually satisfactory?');
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

    final existingItem =
        await _repo?.getCollectionItem('plantRooms', _plantRoomId!) ??
        <String, dynamic>{};
    final existingResponses = (existingItem['responses'] is Map)
        ? Map<String, dynamic>.from(existingItem['responses'] as Map)
        : <String, dynamic>{};
    final newResponses = <String, dynamic>{
      'ph1FreeOfLeaks': _ph1FreeOfLeaks,
      'ph2Corrosion': _ph2Corrosion,
      'ph3Insulated': _ph3Insulated,
      'ph4Supported': _ph4Supported,
      'ph5Overpressure': _ph5Overpressure,
      'ph6WaterValves': _ph6WaterValves,
      'ph7VisuallySatisfactory': _ph7VisuallySatisfactory,
    };
    await _repo?.saveCollectionItem('plantRooms', <String, dynamic>{
      ...existingItem,
      'id': _plantRoomId,
      'responses': {...existingResponses, ...newResponses},
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Hydraulics/System Pipework',
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
                          'Hydraulics/System Pipework',
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
                              'Is the plant room free of water leaks?',
                          questionReference: 'ph1',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph1FreeOfLeaks,
                          onAnswerChanged: (value) =>
                              setState(() => _ph1FreeOfLeaks = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is there any evidence of corrosion within the plant room?',
                          questionReference: 'ph2',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph2Corrosion,
                          onAnswerChanged: (value) =>
                              setState(() => _ph2Corrosion = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is the system pipework sufficiently insulated?',
                          questionReference: 'ph3',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph3Insulated,
                          onAnswerChanged: (value) =>
                              setState(() => _ph3Insulated = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is the system pipework sufficiently supported?',
                          questionReference: 'ph4',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph4Supported,
                          onAnswerChanged: (value) =>
                              setState(() => _ph4Supported = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Has suitable overpressure relief been installed? (If required)',
                          questionReference: 'ph5',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph5Overpressure,
                          onAnswerChanged: (value) =>
                              setState(() => _ph5Overpressure = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Are all water valves/drain valves labelled?',
                          questionReference: 'ph6',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph6WaterValves,
                          onAnswerChanged: (value) =>
                              setState(() => _ph6WaterValves = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Hydraulics visually satisfactory?',
                          questionReference: 'ph7',
                          sectionName: 'Plant Room - Hydraulics',
                          selectedAnswer: _ph7VisuallySatisfactory,
                          onAnswerChanged: (value) =>
                              setState(() => _ph7VisuallySatisfactory = value),
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
