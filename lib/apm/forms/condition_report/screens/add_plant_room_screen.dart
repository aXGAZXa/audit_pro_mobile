import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:image_picker/image_picker.dart';

class AddPlantRoomScreen extends StatefulWidget {
  const AddPlantRoomScreen({super.key});

  @override
  State<AddPlantRoomScreen> createState() => _AddPlantRoomScreenState();
}

class _AddPlantRoomScreenState extends State<AddPlantRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();

  int? _formId;
  Map<String, dynamic>? _existingPlantRoom;

  List<XFile> _plantRoomAccessImages = [];
  List<XFile> _plantRoomInternalImages = [];

  // Subsection data stored per plant room
  final Map<String, dynamic> _plantRoomData = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _formId = args['formId'] as int?;
      _existingPlantRoom = args['plantRoom'] as Map<String, dynamic>?;

      if (_existingPlantRoom != null) {
        // Editing existing plant room
        _locationController.text =
            _existingPlantRoom!['location'] as String? ?? '';

        // Load existing images
        final accessImages = _existingPlantRoom!['accessImages'] as List?;
        if (accessImages != null) {
          _plantRoomAccessImages = accessImages
              .map((path) => XFile(path.toString()))
              .toList()
              .cast<XFile>();
        }

        final internalImages = _existingPlantRoom!['internalImages'] as List?;
        if (internalImages != null) {
          _plantRoomInternalImages = internalImages
              .map((path) => XFile(path.toString()))
              .toList()
              .cast<XFile>();
        }

        // Load subsection data if exists
        _loadSubsectionData();
      }
    }
  }

  Future<void> _loadSubsectionData() async {
    if (_existingPlantRoom == null || _existingPlantRoom!['id'] == null) {
      return;
    }

    final plantRoomId = _existingPlantRoom!['id'] as int;
    final responses = await DatabaseHelper.instance.getPlantRoomResponses(
      plantRoomId,
    );

    if (mounted) {
      setState(() {
        _plantRoomData.clear();
        _plantRoomData.addAll(responses);
      });
    }
  }

  String _toCamelCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _formatLocation() {
    final text = _locationController.text;
    if (text.isNotEmpty) {
      setState(() {
        _locationController.text = _toCamelCase(text);
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _navigateToSubsection(String subsection) async {
    // Save current data first
    await _savePlantRoom();

    if (_existingPlantRoom == null || _existingPlantRoom!['id'] == null) {
      // Show message that plant room must be saved first
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save Required'),
            content: const Text(
              'Please save the plant room before accessing subsections.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/plant-room-$subsection',
      arguments: {'formId': _formId, 'plantRoomId': _existingPlantRoom!['id']},
    );

    if (mounted) {
      // Reload subsection data to update completion status
      await _loadSubsectionData();
    }
  }

  Future<void> _savePlantRoom() async {
    if (_formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Form ID is required')));
      }
      return;
    }

    final plantRoomId = await DatabaseHelper.instance.savePlantRoom(
      id: _existingPlantRoom?['id'] as int?,
      formId: _formId!,
      location: _locationController.text.trim(),
      accessImagePaths: _plantRoomAccessImages.map((img) => img.path).toList(),
      internalImagePaths: _plantRoomInternalImages
          .map((img) => img.path)
          .toList(),
    );

    // Always retain resolved ID locally so subsequent saves update this record.
    _existingPlantRoom = {
      ...?_existingPlantRoom,
      'id': plantRoomId,
      'location': _locationController.text.trim(),
    };

    // Reload subsection data to ensure completion status is current
    await _loadSubsectionData();
  }

  void _saveAndReturn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    List<String> validationErrors = [];

    // Validate location
    if (_locationController.text.trim().isEmpty) {
      validationErrors.add('Please enter a location for the plant room.');
    }

    // Validate at least one access image
    if (_plantRoomAccessImages.isEmpty) {
      validationErrors.add('Please add at least one Plant Room Access image.');
    }

    // Validate at least one internal image
    if (_plantRoomInternalImages.isEmpty) {
      validationErrors.add(
        'Please add at least one Plant Room Internal image.',
      );
    }

    // Validate all subsections complete
    final incompleteSubsections = <String>[];
    if (!_isSubsectionComplete('ventilation')) {
      incompleteSubsections.add('Ventilation');
    }
    if (!_isSubsectionComplete('gas-pipework')) {
      incompleteSubsections.add('Gas Pipework');
    }
    if (!_isSubsectionComplete('general')) {
      incompleteSubsections.add('General');
    }
    if (!_isSubsectionComplete('electrical')) {
      incompleteSubsections.add('Electrical');
    }
    if (!_isSubsectionComplete('hydraulics')) {
      incompleteSubsections.add('Hydraulics/System Pipework');
    }

    if (incompleteSubsections.isNotEmpty) {
      validationErrors.add(
        'Please complete all subsections: ${incompleteSubsections.join(', ')}',
      );
    }

    if (validationErrors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: Text(validationErrors.join('\n\n')),
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

    await _savePlantRoom();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  bool _isSubsectionComplete(String subsection) {
    switch (subsection) {
      case 'ventilation':
        return _plantRoomData['v1Satisfactory'] != null &&
            _plantRoomData['v2Overheating'] != null;
      case 'gas-pipework':
        return _plantRoomData['pi1Supported'] != null &&
            _plantRoomData['pi2Identified'] != null &&
            _plantRoomData['pi3Satisfactory'] != null &&
            _plantRoomData['pi4Sleeved'] != null &&
            _plantRoomData['pi5IsolationValves'] != null &&
            _plantRoomData['pi6EarthBonding'] != null &&
            _plantRoomData['pi7NoSmell'] != null;
      case 'general':
        return _plantRoomData['pg1SafeAccess'] != null &&
            _plantRoomData['pg2Secure'] != null &&
            _plantRoomData['pg3Labelled'] != null &&
            _plantRoomData['pg4AtexLabelling'] != null &&
            _plantRoomData['pg5CanUnlock'] != null &&
            _plantRoomData['pg6FreeOfStoredItems'] != null &&
            _plantRoomData['pg7CleanAndTidy'] != null &&
            _plantRoomData['pg8MaintenanceFile'] != null;
      case 'electrical':
        return _plantRoomData['pe1SufficientlyLit'] != null &&
            _plantRoomData['pe2LightingSuitable'] != null &&
            _plantRoomData['pe3HeatingControls'] != null &&
            _plantRoomData['pe4AutoManualMode'] != null &&
            _plantRoomData['pe5Insulation'] != null &&
            _plantRoomData['pe6ElectricalFittings'] != null &&
            _plantRoomData['pe7CablingContained'] != null &&
            _plantRoomData['pe9EmergencyControls'] != null &&
            _plantRoomData['pe10SystemFitted'] != null &&
            _plantRoomData['pe11LeakSensors'] != null;
      case 'hydraulics':
        return _plantRoomData['ph1FreeOfLeaks'] != null &&
            _plantRoomData['ph2Corrosion'] != null &&
            _plantRoomData['ph3Insulated'] != null &&
            _plantRoomData['ph4Supported'] != null &&
            _plantRoomData['ph5Overpressure'] != null &&
            _plantRoomData['ph6WaterValves'] != null &&
            _plantRoomData['ph7VisuallySatisfactory'] != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingPlantRoom != null;

    return AppScaffold(
      title: isEditing ? 'Edit Plant Room' : 'Add Plant Room',
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
                        // Plant Room Location
                        Text(
                          'Plant Room Location',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _locationController,
                          onEditingComplete: _formatLocation,
                          decoration: const InputDecoration(
                            hintText: 'Enter location',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Plant Room Access Images
                        AppMediaBlock(
                          questionText: 'Plant Room Access',
                          questionReference: 'plantRoomAccessImages',
                          sectionName: 'Plant Room',
                          images: _plantRoomAccessImages,
                          onImagesChanged: (images) {
                            setState(() => _plantRoomAccessImages = images);
                          },
                          formId: _formId,
                          hasObservations: false,
                        ),
                        const SizedBox(height: 24),

                        // Plant Room Internal Images
                        AppMediaBlock(
                          questionText: 'Plant Room Internal',
                          questionReference: 'plantRoomInternalImages',
                          sectionName: 'Plant Room',
                          images: _plantRoomInternalImages,
                          onImagesChanged: (images) {
                            setState(() => _plantRoomInternalImages = images);
                          },
                          formId: _formId,
                          hasObservations: false,
                        ),
                        const SizedBox(height: 24),

                        // Subsection Buttons
                        _SubsectionButton(
                          title: 'Ventilation',
                          isComplete: _isSubsectionComplete('ventilation'),
                          onTap: () => _navigateToSubsection('ventilation'),
                        ),
                        const SizedBox(height: 12),

                        _SubsectionButton(
                          title: 'Gas Pipework',
                          isComplete: _isSubsectionComplete('gas-pipework'),
                          onTap: () => _navigateToSubsection('gas-pipework'),
                        ),
                        const SizedBox(height: 12),

                        _SubsectionButton(
                          title: 'General',
                          isComplete: _isSubsectionComplete('general'),
                          onTap: () => _navigateToSubsection('general'),
                        ),
                        const SizedBox(height: 12),

                        _SubsectionButton(
                          title: 'Electrical',
                          isComplete: _isSubsectionComplete('electrical'),
                          onTap: () => _navigateToSubsection('electrical'),
                        ),
                        const SizedBox(height: 12),

                        _SubsectionButton(
                          title: 'Hydraulics/System Pipework',
                          isComplete: _isSubsectionComplete('hydraulics'),
                          onTap: () => _navigateToSubsection('hydraulics'),
                        ),
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
                  // Cancel Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[900],
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[100],
                        foregroundColor: Colors.green[900],
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(isEditing ? 'UPDATE' : 'SAVE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubsectionButton extends StatelessWidget {
  final String title;
  final bool isComplete;
  final VoidCallback onTap;

  const _SubsectionButton({
    required this.title,
    required this.isComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isComplete
            ? Colors.green[100] // Pastel green for complete
            : Colors.orange[100], // Pastel orange for incomplete
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isComplete ? Icons.check_circle : Icons.arrow_forward,
                color: isComplete ? Colors.green[700] : Colors.orange[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
