import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:image_picker/image_picker.dart';

class PlantRoomScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;

  const PlantRoomScreen({
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
  State<PlantRoomScreen> createState() => _PlantRoomScreenState();
}

class _PlantRoomScreenState extends State<PlantRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();

  List<XFile> _plantRoomAccessImages = [];
  List<XFile> _plantRoomInternalImages = [];

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.formData['plantRoomLocation'] ?? '';

    // Load existing images
    final accessImages = widget.formData['plantRoomAccessImages'];
    if (accessImages != null && accessImages is List) {
      _plantRoomAccessImages = accessImages
          .map((path) => XFile(path.toString()))
          .toList()
          .cast<XFile>();
    }

    final internalImages = widget.formData['plantRoomInternalImages'];
    if (internalImages != null && internalImages is List) {
      _plantRoomInternalImages = internalImages
          .map((path) => XFile(path.toString()))
          .toList()
          .cast<XFile>();
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _saveData() {
    widget.onDataChanged('plantRoomLocation', _locationController.text);
    widget.onDataChanged(
      'plantRoomAccessImages',
      _plantRoomAccessImages.map((img) => img.path).toList(),
    );
    widget.onDataChanged(
      'plantRoomInternalImages',
      _plantRoomInternalImages.map((img) => img.path).toList(),
    );
  }

  void _navigateToSubsection(String subsection) async {
    _saveData();
    await Navigator.pushNamed(
      context,
      '/plant-room-$subsection',
      arguments: {
        'formData': widget.formData,
        'onDataChanged': widget.onDataChanged,
        'formId': widget.formId,
      },
    );
    if (mounted) {
      setState(() {}); // Refresh to show any updated data
    }
  }

  void _saveAndContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      _saveData();
      widget.onNext();
    }
  }

  bool _isSubsectionComplete(String subsection) {
    switch (subsection) {
      case 'ventilation':
        return widget.formData['v1Satisfactory'] != null &&
            widget.formData['v2Overheating'] != null;
      case 'gas-pipework':
        return widget.formData['pi1Supported'] != null &&
            widget.formData['pi2Identified'] != null &&
            widget.formData['pi3Satisfactory'] != null &&
            widget.formData['pi4Sleeved'] != null &&
            widget.formData['pi5IsolationValves'] != null &&
            widget.formData['pi6EarthBonding'] != null &&
            widget.formData['pi7NoSmell'] != null;
      case 'general':
        return widget.formData['g1Tidy'] != null &&
            widget.formData['g2Secure'] != null &&
            widget.formData['g3Emergency'] != null &&
            widget.formData['g4Signage'] != null &&
            widget.formData['g5Hazards'] != null &&
            widget.formData['g6Storage'] != null &&
            widget.formData['g7Damp'] != null &&
            widget.formData['g8Combustibles'] != null;
      case 'electrical':
        return widget.formData['e1Labelled'] != null &&
            widget.formData['e2Suitable'] != null &&
            widget.formData['e3Accessible'] != null &&
            widget.formData['e4Secure'] != null &&
            widget.formData['e5Damaged'] != null &&
            widget.formData['e6RCD'] != null &&
            widget.formData['e7Lighting'] != null &&
            widget.formData['e8Satisfactory'] != null &&
            widget.formData['e9Damage'] != null &&
            widget.formData['e10Overloaded'] != null &&
            widget.formData['e11Condition'] != null;
      case 'hydraulics':
        return widget.formData['h1Supported'] != null &&
            widget.formData['h2Identified'] != null &&
            widget.formData['h3Satisfactory'] != null &&
            widget.formData['h4Leaks'] != null &&
            widget.formData['h5PRV'] != null &&
            widget.formData['h6Expansion'] != null &&
            widget.formData['h7Gauges'] != null;
      default:
        return false;
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
                      // Plant Room Location
                      Text(
                        'Plant Room Location',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          hintText: 'Enter location',
                          border: InputBorder.none,
                        ),
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
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call(
                              'plantRoomAccessImages',
                            ) ??
                            false,
                        onObservationsChanged: widget.onObservationsChanged,
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
                        formId: widget.formId,
                        hasObservations:
                            widget.hasObservations?.call(
                              'plantRoomInternalImages',
                            ) ??
                            false,
                        onObservationsChanged: widget.onObservationsChanged,
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
