import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../components/form_widgets.dart';
import '../../../services/form_validation_feedback.dart';
import '../../../services/platform/image_persistence.dart';

class HnaUnsafeReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? report;
  final List<Map<String, dynamic>> unsafeObservationsJson;
  final List<Map<String, dynamic>> unreportedUnsafeObservationsJson;
  final VoidCallback onBack;
  final ValueChanged<Map<String, dynamic>> onSave;

  const HnaUnsafeReportDetailsScreen({
    super.key,
    required this.report,
    required this.unsafeObservationsJson,
    required this.unreportedUnsafeObservationsJson,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<HnaUnsafeReportDetailsScreen> createState() =>
      _HnaUnsafeReportDetailsScreenState();
}

class _HnaUnsafeReportDetailsScreenState
    extends State<HnaUnsafeReportDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  final Set<String> _selectedObsIds = <String>{};
  late final List<Map<String, dynamic>> _allUnsafeObservations;

  final TextEditingController _actionTakenController = TextEditingController();
  final TextEditingController _reportedToClientController =
      TextEditingController();
  final TextEditingController _reportedInternallyController =
      TextEditingController();
  final FocusNode _clientFocusNode = FocusNode();
  final FocusNode _internalFocusNode = FocusNode();

  String? _afterImagePath;
  String? _warningNoticeImagePath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Add listeners to capitalize names on focus loss
    _clientFocusNode.addListener(() {
      if (!_clientFocusNode.hasFocus) {
        _capitalizeName(_reportedToClientController);
      }
    });
    _internalFocusNode.addListener(() {
      if (!_internalFocusNode.hasFocus) {
        _capitalizeName(_reportedInternallyController);
      }
    });

    _hydrateFromInputs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actionTakenController.dispose();
    _reportedToClientController.dispose();
    _reportedInternallyController.dispose();
    _clientFocusNode.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _capitalizeName(TextEditingController controller) {
    final text = controller.text;
    if (text.isEmpty) return;

    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final capitalizedText = capitalizedWords.join(' ');
    if (capitalizedText != text) {
      controller.value = TextEditingValue(
        text: capitalizedText,
        selection: TextSelection.collapsed(offset: capitalizedText.length),
      );
    }
  }

  void _hydrateFromInputs() {
    final byId = <String, Map<String, dynamic>>{};
    var tmpIndex = 0;
    for (final obs in [
      ...widget.unsafeObservationsJson,
      ...widget.unreportedUnsafeObservationsJson,
    ]) {
      final id = obs['id'];
      final key = (id == null || id.toString().trim().isEmpty)
          ? 'tmp_${tmpIndex++}'
          : id.toString();
      byId.putIfAbsent(key, () => obs);
    }
    _allUnsafeObservations = byId.values.toList(growable: false);

    final report = widget.report;
    if (report != null) {
      final ids = report['observationIds'] ?? report['observation_ids'];
      if (ids is List) {
        for (final x in ids) {
          final s = x?.toString().trim();
          if (s != null && s.isNotEmpty) _selectedObsIds.add(s);
        }
      }

      _actionTakenController.text =
          (report['actionTaken'] ?? report['action_taken'] ?? '').toString();
      _afterImagePath = (report['afterImage'] ?? report['after_image'])
          ?.toString();
      _warningNoticeImagePath =
          (report['warningNoticeImage'] ?? report['warning_notice_image'])
              ?.toString();
      _reportedToClientController.text =
          (report['reportedToClient'] ?? report['reported_to_client'] ?? '')
              .toString();
      _reportedInternallyController.text =
          (report['reportedInternally'] ?? report['reported_internally'] ?? '')
              .toString();

      return;
    }

    // New report: pre-select currently unreported observations
    for (final obs in widget.unreportedUnsafeObservationsJson) {
      final id = obs['id']?.toString().trim();
      if (id != null && id.isNotEmpty) _selectedObsIds.add(id);
    }
  }

  String _labelForObservation(Map<String, dynamic> obs) {
    final assetId = obs['asset_id'];
    if (assetId != null) {
      final assetType = (obs['asset_type'] ?? '').toString();
      final assetMakeModel = (obs['asset_make_model'] ?? '').toString();
      if (assetMakeModel.trim().isNotEmpty) {
        return '$assetType: $assetMakeModel';
      }
      return assetType.trim().isEmpty ? 'Asset Observation' : assetType;
    }

    final sectionName = obs['section_name'];
    final questionText = obs['question_text'];
    if (sectionName != null && questionText != null) {
      return '${sectionName.toString()}: ${questionText.toString()}';
    }
    if (questionText != null) return questionText.toString();

    return (obs['question_reference'] ?? 'Observation').toString();
  }

  String? _classificationForObservation(Map<String, dynamic> obs) {
    final raw = obs['unsafe_classification'] ?? obs['unsafeClassification'];
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedObsIds.add(id);
      } else {
        _selectedObsIds.remove(id);
      }
    });
  }

  Future<void> _captureImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final paths = await persistPickedImagePaths([
        image,
      ], prefix: 'unsafe_$type');
      final savedPath = paths.isNotEmpty ? paths.first : image.path;

      setState(() {
        if (type == 'after') {
          _afterImagePath = savedPath;
        } else if (type == 'warning_notice') {
          _warningNoticeImagePath = savedPath;
        }
      });
    }
  }

  Future<void> _saveReport() async {
    if (!FormValidationFeedback.validate(
      context,
      _formKey,
      scrollController: _scrollController,
    )) {
      return;
    }

    if (_selectedObsIds.isEmpty) {
      FormValidationFeedback.showValidationError(
        context,
        message: 'Please select at least one observation.',
        scrollController: _scrollController,
      );
      return;
    }

    if (_afterImagePath == null) {
      FormValidationFeedback.showValidationError(
        context,
        message: 'Please capture an After Image.',
        scrollController: _scrollController,
      );
      return;
    }

    if (_warningNoticeImagePath == null) {
      FormValidationFeedback.showValidationError(
        context,
        message: 'Please capture a Warning Notice Image.',
        scrollController: _scrollController,
      );
      return;
    }

    setState(() => _isSaving = true);

    final existing = widget.report;
    final idRaw = existing?['id'];
    final id = (idRaw == null || idRaw.toString().trim().isEmpty)
        ? DateTime.now().millisecondsSinceEpoch
        : idRaw;

    final createdAtRaw = existing?['createdAt'] ?? existing?['created_at'];
    final createdAt =
        (createdAtRaw == null || createdAtRaw.toString().trim().isEmpty)
        ? DateTime.now().toIso8601String()
        : createdAtRaw.toString();

    widget.onSave({
      ...(existing ?? const <String, dynamic>{}),
      'id': id,
      'createdAt': createdAt,
      'observationIds': _selectedObsIds.toList(growable: false),
      'actionTaken': _actionTakenController.text.trim(),
      'warningNoticeImage': _warningNoticeImagePath,
      'afterImage': _afterImagePath,
      'reportedToClient': _reportedToClientController.text.trim(),
      'reportedInternally': _reportedInternallyController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.report != null
                ? 'Edit Unsafe Report'
                : 'Create Unsafe Report',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Observations (${_selectedObsIds.length} selected)',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose which unsafe observations to include in this report',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),

                          if (_allUnsafeObservations.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'No unsafe observations available',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            )
                          else
                            ..._allUnsafeObservations.map((observation) {
                              final id =
                                  observation['id']?.toString().trim() ?? '';
                              final enabled = id.isNotEmpty;
                              final isSelected =
                                  enabled && _selectedObsIds.contains(id);

                              final notes =
                                  (observation['notes'] ?? 'No details')
                                      .toString();
                              final label = _labelForObservation(observation);
                              final classification =
                                  _classificationForObservation(observation);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: isSelected ? 0 : 1,
                                color: isSelected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: enabled
                                      ? () => _toggle(id, !isSelected)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                label,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (classification != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: classification == 'ID'
                                                      ? Colors.red[100]
                                                      : Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  classification,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        classification == 'ID'
                                                        ? Colors.red[900]
                                                        : Colors.orange[900],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 24),
                          Text(
                            'Action Taken',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _actionTakenController,
                            decoration: const InputDecoration(
                              labelText: 'Responsive actions taken? *',
                              hintText:
                                  'Describe the immediate actions taken...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please describe the actions taken';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),
                          Text(
                            'After Image *',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photo documenting the action taken',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (_afterImagePath != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppResolvedImage(
                                    imagePath: _afterImagePath!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() => _afterImagePath = null);
                                    },
                                  ),
                                ),
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _captureImage('after'),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Capture After Image'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),

                          const SizedBox(height: 16),
                          Text(
                            'Warning Notice Image *',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photo of warning notice left onsite',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (_warningNoticeImagePath != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppResolvedImage(
                                    imagePath: _warningNoticeImagePath!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _warningNoticeImagePath = null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _captureImage('warning_notice'),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Capture Warning Notice'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),

                          const SizedBox(height: 24),
                          Text(
                            'Reporting Details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _reportedToClientController,
                            focusNode: _clientFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Client representative reported to: *',
                              hintText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter who was reported to at client';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _reportedInternallyController,
                            focusNode: _internalFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Reported internally to: *',
                              hintText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter who was reported to internally';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : widget.onBack,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[100],
                            foregroundColor: Colors.red[900],
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[100],
                            foregroundColor: Colors.green[900],
                            minimumSize: const Size(0, 48),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(widget.report != null ? 'UPDATE' : 'SAVE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
