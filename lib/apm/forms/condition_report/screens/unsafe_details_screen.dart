import 'dart:developer' as developer;
import 'dart:io';

import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UnsafeDetailsScreen extends StatefulWidget {
  final int formId;
  final int? reportId; // null = create new, int = edit existing
  final VoidCallback onBack;
  final VoidCallback onSave;

  /// Injected I/O (Condition Report). When present, the report is written
  /// through the single-writer document; reads (derived) stay on DatabaseHelper.
  final FormRepository? repo;

  const UnsafeDetailsScreen({
    super.key,
    required this.formId,
    this.reportId,
    required this.onBack,
    required this.onSave,
    this.repo,
  });

  @override
  State<UnsafeDetailsScreen> createState() => _UnsafeDetailsScreenState();
}

class _UnsafeDetailsScreenState extends State<UnsafeDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // All unsafe observations for the form
  List<Map<String, dynamic>> _allUnsafeObservations = [];

  // Selected observation IDs
  Set<int> _selectedObservationIds = {};

  // Report fields
  final TextEditingController _actionTakenController = TextEditingController();
  String? _afterImagePath;
  String? _warningNoticeImagePath;
  final TextEditingController _reportedToClientController =
      TextEditingController();
  final TextEditingController _reportedInternallyController =
      TextEditingController();
  final FocusNode _clientFocusNode = FocusNode();
  final FocusNode _internalFocusNode = FocusNode();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();

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
  }

  @override
  void dispose() {
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

    // Convert to title case (capitalize first letter of each word)
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load all unsafe observations for this form
      final observations = await DatabaseHelper.instance.getUnsafeObservations(
        widget.formId,
      );

      // If editing existing report, load its data
      Map<String, dynamic>? existingReport;
      if (widget.reportId != null) {
        existingReport = await DatabaseHelper.instance.getUnsafeReport(
          widget.reportId!,
        );
      }

      if (mounted) {
        // Pre-select observations
        Set<int> selectedIds = {};
        if (existingReport != null) {
          // Pre-select observations in this report
          final reportObservations =
              existingReport['observations'] as List<dynamic>? ?? [];
          selectedIds = reportObservations
              .map((obs) => obs['id'] as int)
              .toSet();
        } else {
          // New report: pre-select unreported observations
          final unreported = await DatabaseHelper.instance
              .getUnreportedUnsafeObservations(widget.formId);
          selectedIds = unreported.map((obs) => obs['id'] as int).toSet();
        }

        setState(() {
          _allUnsafeObservations = observations;

          if (existingReport != null) {
            // Load report data
            _actionTakenController.text = existingReport['action_taken'] ?? '';
            _afterImagePath = existingReport['after_image'];
            _warningNoticeImagePath = existingReport['warning_notice_image'];
            _reportedToClientController.text =
                existingReport['reported_to_client'] ?? '';
            _reportedInternallyController.text =
                existingReport['reported_internally'] ?? '';
          }

          _selectedObservationIds = selectedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ApmFeedback.error(context, 'Error loading data: $e');
      }
    }
  }

  Future<void> _captureImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type.jpg';
      final savedImage = File(p.join(appDir.path, fileName));
      await File(image.path).copy(savedImage.path);

      setState(() {
        if (type == 'after') {
          _afterImagePath = savedImage.path;
        } else if (type == 'warning_notice') {
          _warningNoticeImagePath = savedImage.path;
        }
      });
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedObservationIds.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please select at least one observation'),
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

    // Validate required images
    if (_afterImagePath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please capture an After Image'),
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

    if (_warningNoticeImagePath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please capture a Warning Notice Image'),
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

    setState(() => _isSaving = true);

    try {
      final repo = widget.repo;
      if (repo != null) {
        // Single-writer: upsert the report into the form document, preserving
        // the exact shape DatabaseHelper.saveUnsafeReport produces.
        final reportId = widget.reportId;
        final existing = reportId != null
            ? await repo.getCollectionItem('unsafeReports', reportId)
            : null;
        final ids = _selectedObservationIds.toList();
        // Stable cross-environment FK: link selected observations by their
        // UUID (additive to the local int observation_ids) so the server can
        // reconcile by a key that survives edits / re-projection / devices.
        final observationUuids = _allUnsafeObservations
            .where((o) => _selectedObservationIds.contains(o['id']))
            .map((o) => (o['uuid'] ?? '').toString())
            .where((u) => u.isNotEmpty)
            .toList();
        final now = DateTime.now().toIso8601String();
        await repo.saveCollectionItem('unsafeReports', <String, dynamic>{
          ...?existing,
          if (reportId != null) 'id': reportId,
          'form_id': widget.formId,
          'action_taken': _actionTakenController.text.trim(),
          'warning_notice_image': _warningNoticeImagePath,
          'after_image': _afterImagePath,
          'reported_to_client': _reportedToClientController.text.trim(),
          'reported_internally': _reportedInternallyController.text.trim(),
          'observation_ids': ids,
          'observation_uuids': observationUuids,
          'observation_count': ids.length,
          'created_at': existing?['created_at'] ?? now,
          'updated_at': now,
        });
      } else {
        await DatabaseHelper.instance.saveUnsafeReport(
          id: widget.reportId,
          formId: widget.formId,
          actionTaken: _actionTakenController.text.trim(),
          warningNoticeImage: _warningNoticeImagePath,
          afterImage: _afterImagePath,
          reportedToClient: _reportedToClientController.text.trim(),
          reportedInternally: _reportedInternallyController.text.trim(),
          observationIds: _selectedObservationIds.toList(),
        );
      }

      if (mounted) {
        widget.onSave();
      }
    } catch (e) {
      developer.log('Error saving report: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ApmFeedback.error(context, 'Error saving report: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.reportId != null
                ? 'Edit Unsafe Report'
                : 'Create Unsafe Report',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Select Observations Section
                                Text(
                                  'Select Observations (${_selectedObservationIds.length} selected)',
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
                                        'No unsafe observations found for this form',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )
                                else
                                  ..._allUnsafeObservations.map((observation) {
                                    final observationId =
                                        observation['id'] as int;
                                    final isSelected = _selectedObservationIds
                                        .contains(observationId);
                                    final notes =
                                        observation['notes'] as String? ??
                                        'No details';

                                    final classification =
                                        observation['unsafe_classification']
                                            as String?;

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
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedObservationIds.remove(
                                                observationId,
                                              );
                                            } else {
                                              _selectedObservationIds.add(
                                                observationId,
                                              );
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            notes,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ),
                                                        if (classification !=
                                                            null) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  classification ==
                                                                      'ID'
                                                                  ? Colors
                                                                        .red[100]
                                                                  : Colors
                                                                        .orange[100],
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              classification,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    classification ==
                                                                        'ID'
                                                                    ? Colors
                                                                          .red[900]
                                                                    : Colors
                                                                          .orange[900],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
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
                                    labelText: 'Action Taken by Auditor *',
                                    hintText:
                                        'Describe the immediate action taken...',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 4,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please describe the action taken';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // After Image
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
                                            setState(
                                              () => _afterImagePath = null,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () => _captureImage('after'),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Capture After Image'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // Warning Notice Image
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
                                              () => _warningNoticeImagePath =
                                                  null,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _captureImage('warning_notice'),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Capture Warning Notice'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
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
                                    labelText:
                                        'Client representative reported to: *',
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
                            // Cancel Button
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
                            // Save Button
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
                                    : Text(
                                        widget.reportId != null
                                            ? 'UPDATE'
                                            : 'SAVE',
                                      ),
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
