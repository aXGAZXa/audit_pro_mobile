import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';

class PlantRoomGeneralScreen extends StatefulWidget {
  const PlantRoomGeneralScreen({super.key});

  @override
  State<PlantRoomGeneralScreen> createState() => _PlantRoomGeneralScreenState();
}

class _PlantRoomGeneralScreenState extends State<PlantRoomGeneralScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _formId;
  int? _plantRoomId;

  String? _pg1SafeAccess;
  String? _pg2Secure;
  String? _pg3Labelled;
  String? _pg4AtexLabelling;
  String? _pg5CanUnlock;
  String? _pg6FreeOfStoredItems;
  String? _pg7CleanAndTidy;
  String? _pg8MaintenanceFile;

  void _setAllAnswersToYes() {
    setState(() {
      _pg1SafeAccess = 'YES';
      _pg2Secure = 'YES';
      _pg3Labelled = 'YES';
      _pg4AtexLabelling = 'YES';
      _pg5CanUnlock = 'YES';
      _pg6FreeOfStoredItems = 'YES';
      _pg7CleanAndTidy = 'YES';
      _pg8MaintenanceFile = 'YES';
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
        _pg1SafeAccess = responses['pg1SafeAccess'];
        _pg2Secure = responses['pg2Secure'];
        _pg3Labelled = responses['pg3Labelled'];
        _pg4AtexLabelling = responses['pg4AtexLabelling'];
        _pg5CanUnlock = responses['pg5CanUnlock'];
        _pg6FreeOfStoredItems = responses['pg6FreeOfStoredItems'];
        _pg7CleanAndTidy = responses['pg7CleanAndTidy'];
        _pg8MaintenanceFile = responses['pg8MaintenanceFile'];
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
    if (_pg1SafeAccess == null) missingAnswers.add('Safe access?');
    if (_pg2Secure == null) missingAnswers.add('Secure?');
    if (_pg3Labelled == null) missingAnswers.add('Labelled?');
    if (_pg4AtexLabelling == null) missingAnswers.add('ATEX labelling?');
    if (_pg5CanUnlock == null) missingAnswers.add('Can unlock?');
    if (_pg6FreeOfStoredItems == null) {
      missingAnswers.add('Free of stored items?');
    }
    if (_pg7CleanAndTidy == null) missingAnswers.add('Clean and tidy?');
    if (_pg8MaintenanceFile == null) missingAnswers.add('Maintenance file?');

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
        'pg1SafeAccess': _pg1SafeAccess,
        'pg2Secure': _pg2Secure,
        'pg3Labelled': _pg3Labelled,
        'pg4AtexLabelling': _pg4AtexLabelling,
        'pg5CanUnlock': _pg5CanUnlock,
        'pg6FreeOfStoredItems': _pg6FreeOfStoredItems,
        'pg7CleanAndTidy': _pg7CleanAndTidy,
        'pg8MaintenanceFile': _pg8MaintenanceFile,
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'General',
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
                          'General',
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
                              'Is suitable safe access provided to the plant room?',
                          questionReference: 'pg1',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg1SafeAccess,
                          onAnswerChanged: (value) =>
                              setState(() => _pg1SafeAccess = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Is the plant room secure?',
                          questionReference: 'pg2',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg2Secure,
                          onAnswerChanged: (value) =>
                              setState(() => _pg2Secure = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is the plant room access suitably labelled?',
                          questionReference: 'pg3',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg3Labelled,
                          onAnswerChanged: (value) =>
                              setState(() => _pg3Labelled = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Is suitable ATEX labelling present?',
                          questionReference: 'pg4',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg4AtexLabelling,
                          onAnswerChanged: (value) =>
                              setState(() => _pg4AtexLabelling = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Can the plant room be unlocked from inside without the use of a key?',
                          questionReference: 'pg5',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg5CanUnlock,
                          onAnswerChanged: (value) =>
                              setState(() => _pg5CanUnlock = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is the plant room free of stored items?',
                          questionReference: 'pg6',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg6FreeOfStoredItems,
                          onAnswerChanged: (value) =>
                              setState(() => _pg6FreeOfStoredItems = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText: 'Is the plant room clean and tidy?',
                          questionReference: 'pg7',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg7CleanAndTidy,
                          onAnswerChanged: (value) =>
                              setState(() => _pg7CleanAndTidy = value),
                          formId: _formId,
                          hasObservations: false,
                        ),
                        AppQuestionBlock(
                          questionText:
                              'Is an Operation & Maintenance file available in the plant room?',
                          questionReference: 'pg8',
                          sectionName: 'Plant Room - General',
                          selectedAnswer: _pg8MaintenanceFile,
                          onAnswerChanged: (value) =>
                              setState(() => _pg8MaintenanceFile = value),
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
