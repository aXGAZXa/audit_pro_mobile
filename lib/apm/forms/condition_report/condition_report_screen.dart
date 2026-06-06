import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/condition_report/services/cr_submission_service.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/site_details_screen.dart';
import 'screens/gas_meter_screen.dart';
import 'screens/infrastructure_outside_screen.dart';
import 'screens/site_assets_screen.dart';
import 'screens/assets_continued_screen.dart';
import 'screens/plant_rooms_list_screen.dart';
import 'screens/communal_heating_system_screen.dart';
import 'screens/unsafe_situations_screen.dart';
import 'screens/summary_signature_screen.dart';
import '../shared/editor/form_editor_contract.dart';
import '../shared/editor/form_draft_persistence_service.dart';
import 'condition_report_definition.dart';

class ConditionReportScreen extends StatefulWidget {
  final int? formId; // Optional form ID to load specific form
  final bool forceNew; // Force creation of new form (ignore existing drafts)
  final FormEditorRuntimeMode mode;
  final Map<String, dynamic>? initialFormData;
  final FormEditorCompleteHandler? onCompleteForm;

  const ConditionReportScreen({
    super.key,
    this.formId,
    this.forceNew = false,
    this.mode = FormEditorRuntimeMode.mobileDraft,
    this.initialFormData,
    this.onCompleteForm,
  });

  @override
  State<ConditionReportScreen> createState() => _ConditionReportScreenState();
}

class _ConditionReportScreenState extends State<ConditionReportScreen> {
  final PageController _pageController = PageController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final FormDraftPersistenceService _draftPersistence =
      FormDraftPersistenceService();
  final CrSubmissionService _submissionService = CrSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );

  bool get _isWebEditorMode => widget.mode == FormEditorRuntimeMode.webEditor;

  int _currentPage = 0;
  int? _formId; // Database ID for this form instance
  static const FormSavePolicy _autosavePolicy = FormSavePolicy(
    debounce: Duration(milliseconds: 700),
  );

  // Form data that persists across screens
  final Map<String, dynamic> _formData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_isWebEditorMode) {
      try {
        _formId = null;
        _formData
          ..clear()
          ..addAll(
            _convertFromSerializable(
                  widget.initialFormData ?? const <String, dynamic>{},
                )
                as Map<String, dynamic>,
          );
        _refreshObservationFlagsFromFormData();
      } catch (e) {
        developer.log('Error initializing CR web editor mode: $e');
      } finally {
        _isLoading = false;
      }
      return;
    }

    _loadOrCreateForm();
  }

  /// Load existing draft form or create a new one
  Future<void> _loadOrCreateForm() async {
    setState(() => _isLoading = true);

    try {
      // If a specific form ID was provided, load that form
      final session = await _draftPersistence.loadOrCreate(
        formType: kConditionReportFormType,
        explicitFormId: widget.formId,
        forceNew: widget.forceNew,
        allowLatestDraftFallback: true,
        initialFormData: const <String, dynamic>{},
      );
      _formId = session.formId;
      final loadedData = Map<String, dynamic>.from(session.formData);
      _formData
        ..clear()
        ..addAll(_convertFromSerializable(loadedData) as Map<String, dynamic>);
      developer.log('Loaded draft session with ID: $_formId');

      // Load observations for all questions
      await _loadObservations();
    } catch (e) {
      developer.log('Error in _loadOrCreateForm: $e');
      if (mounted) {
        ApmFeedback.error(context, 'Error loading form: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load all observations for the current form
  Future<void> _loadObservations() async {
    if (_isWebEditorMode) {
      _refreshObservationFlagsFromFormData();
      return;
    }

    if (_formId == null) return;

    try {
      final observations = await _db.getFormObservations(_formId!);

      setState(() {
        // Clear existing observation flags
        _formData.removeWhere((key, value) => key.endsWith('HasObservations'));

        // Track which questions have observations
        for (final obs in observations) {
          final questionRef = obs['question_reference'];
          _formData['${questionRef}HasObservations'] = true;
        }
      });
    } catch (e) {
      developer.log('Error loading observations: $e');
    }
  }

  /// Check if a question has observations
  bool _hasObservations(String questionRef) {
    return _formData['${questionRef}HasObservations'] == true;
  }

  void _refreshObservationFlagsFromFormData() {
    _formData.removeWhere((key, value) => key.endsWith('HasObservations'));

    final observationsRaw = _formData['observations'];
    if (observationsRaw is! List) return;

    for (final row in observationsRaw) {
      if (row is! Map) continue;
      final questionRef = (row['question_reference'] ?? '').toString().trim();
      if (questionRef.isEmpty) continue;
      _formData['${questionRef}HasObservations'] = true;
    }
  }

  List<Map<String, dynamic>> _unsafeObservationsFromFormData() {
    final out = <Map<String, dynamic>>[];
    final observationsRaw = _formData['observations'];
    if (observationsRaw is! List) return out;

    for (final item in observationsRaw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final flag = row['is_unsafe'];
      final isUnsafe =
          flag == true || flag == 1 || (flag?.toString().trim() == '1');
      if (isUnsafe) out.add(row);
    }

    return out;
  }

  @override
  void dispose() {
    _draftPersistence.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    // Wait a brief moment for any pending setState calls to complete
    await Future.delayed(const Duration(milliseconds: 50));

    if (_currentPage < 8) {
      // Updated to 9 screens (0=site, 1=gas, 2=infrastructure, 3=assets, 4=assets_continued, 5=plant_room, 6=communal_heating, 7=unsafe_situations, 8=summary_signature)
      if (!_isWebEditorMode && _formId != null) {
        await _draftPersistence.flush(
          formType: kConditionReportFormType,
          formId: _formId!,
        );
      }
      await _saveForm(); // Auto-save on navigation

      // Skip Unsafe Situations screen (page 7) if no unsafe observations
      if (_currentPage == 6) {
        final unsafeObservations = _isWebEditorMode
            ? _unsafeObservationsFromFormData()
            : (_formId == null
                  ? const <Map<String, dynamic>>[]
                  : await _db.getUnsafeObservations(_formId!));
        if (unsafeObservations.isEmpty) {
          // Skip directly to Summary & Signature (page 8)
          _pageController.animateToPage(
            8,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _previousPage() async {
    // Wait a brief moment for any pending setState calls to complete
    await Future.delayed(const Duration(milliseconds: 50));

    if (_currentPage > 0) {
      if (!_isWebEditorMode && _formId != null) {
        await _draftPersistence.flush(
          formType: kConditionReportFormType,
          formId: _formId!,
        );
      }
      await _saveForm(); // Auto-save on navigation

      // Skip Unsafe Situations screen (page 7) if no unsafe observations when going back
      if (_currentPage == 8) {
        final unsafeObservations = _isWebEditorMode
            ? _unsafeObservationsFromFormData()
            : (_formId == null
                  ? const <Map<String, dynamic>>[]
                  : await _db.getUnsafeObservations(_formId!));
        if (unsafeObservations.isEmpty) {
          // Skip back to Communal Heating (page 6)
          _pageController.animateToPage(
            6,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }
      }

      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateFormData(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });

    if (!_isWebEditorMode) {
      _saveForm(savePolicy: _autosavePolicy);
    }

    // Auto-save observations to database
    if (key.endsWith('Observation') && value != null) {
      _saveObservation(key, value as Map<String, dynamic>);
    }
  }

  /// Save the current form state to database
  Future<void> _saveForm({
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) async {
    if (_isWebEditorMode) {
      return;
    }

    if (_formId == null) return;

    try {
      developer.log('Saving form data: ${_formData.keys.toList()}');

      // Get current form to preserve status and DB-managed entity collections.
      final currentForm = await _db.getForm(_formId!);
      final currentStatus = currentForm?['status'] ?? 'draft';

      // Convert DateTime objects to ISO strings and merge with latest persisted
      // entity collections so parent autosave does not wipe subsection data.
      final dataToSave = _buildMergedFormDataForSave(currentForm);

      await _draftPersistence.save(
        formType: kConditionReportFormType,
        formId: _formId!,
        status: currentStatus, // Preserve existing status
        formData: Map<String, dynamic>.from(dataToSave),
        keepCurrentPointer: currentStatus == 'draft',
        savePolicy: savePolicy,
      );
      developer.log(
        'Form saved successfully with ID: $_formId, status: $currentStatus',
      );
    } catch (e) {
      developer.log('Error saving form: $e');
      if (mounted) {
        ApmFeedback.error(context, 'Error saving form: $e');
      }
    }
  }

  /// Complete the form and attempt immediate submit.
  /// On failure, keep as pending in My Forms for manual retry.
  Future<void> _completeForm() async {
    if (!_isWebEditorMode && _formId == null) return;

    try {
      late final Map<String, dynamic> dataToSave;
      if (_isWebEditorMode) {
        dataToSave = Map<String, dynamic>.from(
          _convertToSerializable(_formData) as Map<String, dynamic>,
        );
      } else {
        // Preserve DB-managed entity collections during completion save too.
        final currentForm = await _db.getForm(_formId!);
        dataToSave = _buildMergedFormDataForSave(currentForm);

        // Once completed, no longer treat this as the active in-progress draft.
        await _draftPersistence.clearCurrentDraft(kConditionReportFormType);

        await _draftPersistence.flush(
          formType: kConditionReportFormType,
          formId: _formId!,
        );

        await _draftPersistence.save(
          formType: kConditionReportFormType,
          formId: _formId!,
          status: 'pending',
          formData: Map<String, dynamic>.from(dataToSave),
          keepCurrentPointer: false,
        );
      }

      if (widget.onCompleteForm != null) {
        await widget.onCompleteForm!(
          FormEditorCompletion(
            formType: kConditionReportFormType,
            formData: Map<String, dynamic>.from(dataToSave),
            localFormId: _formId,
            formUuid: (_formData['uuid'] ?? '').toString().trim().isEmpty
                ? null
                : (_formData['uuid'] ?? '').toString().trim(),
          ),
        );
        return;
      }

      if (_isWebEditorMode) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      try {
        await _submissionService.submitForm(formId: _formId!);
        if (!mounted) return;
        ApmFeedback.success(context, 'Form submitted.');
      } catch (e) {
        if (!mounted) return;
        ApmFeedback.error(
          context,
          'Upload failed. Saved to My Forms for retry.\n$e',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      developer.log('Error completing form: $e');
      if (mounted) {
        ApmFeedback.error(context, 'Error completing form: $e');
      }
    }
  }

  /// Recursively convert DateTime and other non-serializable objects
  dynamic _convertToSerializable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            _convertToSerializable(entry.value),
          ),
        ),
      );
    }
    if (value is List) {
      return value.map((item) => _convertToSerializable(item)).toList();
    }
    return value;
  }

  /// Convert from serialized format back to runtime format
  /// Handles ISO date strings -> DateTime conversion
  dynamic _convertFromSerializable(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Try to parse as DateTime if it looks like an ISO8601 string
      if (value.contains('T') && value.contains(':')) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return value;
        }
      }
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            _convertFromSerializable(entry.value),
          ),
        ),
      );
    }
    if (value is List) {
      return value.map((item) => _convertFromSerializable(item)).toList();
    }
    return value;
  }

  Map<String, dynamic> _buildMergedFormDataForSave(
    Map<String, dynamic>? currentForm,
  ) {
    final dataToSave = Map<String, dynamic>.from(
      _convertToSerializable(_formData) as Map<String, dynamic>,
    );

    final persistedRaw = currentForm?['form_data'];
    if (persistedRaw is! Map) {
      return dataToSave;
    }

    final persisted = Map<String, dynamic>.from(persistedRaw);

    // These collections are persisted via DatabaseHelper entity operations and
    // should not be replaced by potentially stale parent-screen state.
    const dbManagedCollections = <String>[
      'observations',
      'plantRooms',
      'assets',
      'unsafeReports',
    ];
    for (final key in dbManagedCollections) {
      if (persisted.containsKey(key)) {
        dataToSave[key] = persisted[key];
      }
    }

    return dataToSave;
  }

  /// Save an observation to the database
  Future<void> _saveObservation(
    String key,
    Map<String, dynamic> observationData,
  ) async {
    if (_isWebEditorMode) {
      final questionRef = key.replaceAll('Observation', '');
      final notes = observationData['notes'] as String?;
      final xFiles = observationData['images'] as List<XFile>?;
      final imagePaths = xFiles?.map((xFile) => xFile.path).toList() ?? [];

      final observationsRaw = _formData['observations'];
      final observations = observationsRaw is List
          ? observationsRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true)
          : <Map<String, dynamic>>[];

      final existingIndex = observations.indexWhere(
        (row) => (row['question_reference'] ?? '').toString() == questionRef,
      );

      final now = DateTime.now().toUtc().toIso8601String();
      final nextId = existingIndex >= 0
          ? (int.tryParse(
                  observations[existingIndex]['id']?.toString() ?? '',
                ) ??
                existingIndex + 1)
          : observations.length + 1;

      final next = <String, dynamic>{
        ...(existingIndex >= 0
            ? observations[existingIndex]
            : <String, dynamic>{}),
        'id': nextId,
        'question_reference': questionRef,
        'notes': notes?.isEmpty ?? true ? null : notes,
        'images': imagePaths,
        'is_unsafe': existingIndex >= 0
            ? observations[existingIndex]['is_unsafe']
            : 0,
        'updated_at': now,
        'created_at': existingIndex >= 0
            ? observations[existingIndex]['created_at'] ?? now
            : now,
      };

      if (existingIndex >= 0) {
        observations[existingIndex] = next;
      } else {
        observations.add(next);
      }

      setState(() {
        _formData['observations'] = observations;
        _refreshObservationFlagsFromFormData();
      });
      return;
    }

    if (_formId == null) return;

    try {
      // Extract question reference from key (e.g., 'g1Observation' -> 'g1')
      final questionRef = key.replaceAll('Observation', '');

      final notes = observationData['notes'] as String?;
      final xFiles = observationData['images'] as List<XFile>?;
      final imagePaths = xFiles?.map((xFile) => xFile.path).toList() ?? [];

      await _db.saveObservation(
        formId: _formId!,
        questionReference: questionRef,
        notes: notes?.isEmpty ?? true ? null : notes,
        imagePaths: imagePaths,
      );
    } catch (e) {
      developer.log('Error saving observation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        title: 'Condition Report',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Condition Report',
      body: PageView(
        controller: _pageController,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          SiteDetailsScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            formId: _formId,
            isWebEditorMode: _isWebEditorMode,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          GasMeterScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          InfrastructureOutsideScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          SiteAssetsScreen(
            formData: _formData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            mode: widget.mode,
            onDataChanged: _updateFormData,
          ),
          AssetsContinuedScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          PlantRoomsListScreen(
            formData: _formData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            mode: widget.mode,
            onDataChanged: _updateFormData,
          ),
          CommunalHeatingSystemScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
          ),
          UnsafeSituationsScreen(
            formData: _formData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
          ),
          SummarySignatureScreen(
            formData: _formData,
            onDataChanged: _updateFormData,
            onBack: _previousPage,
            onComplete: _completeForm,
            formId: _formId,
          ),
        ],
      ),
    );
  }
}
