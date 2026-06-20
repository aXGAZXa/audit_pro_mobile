import 'dart:developer' as developer;

import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/editor/form_editor_contract.dart';
import 'condition_report_definition.dart';
import 'services/cr_observation_record.dart';
import 'screens/assets_continued_screen.dart';
import 'screens/communal_heating_system_screen.dart';
import 'screens/gas_meter_screen.dart';
import 'screens/infrastructure_outside_screen.dart';
import 'screens/plant_rooms_list_screen.dart';
import 'screens/site_assets_screen.dart';
import 'screens/site_details_screen.dart';
import 'screens/summary_signature_screen.dart';
import 'screens/unsafe_situations_screen.dart';

/// Condition Report editor — one screen, both platforms. All I/O goes through
/// the injected [FormRepository] (SQLite on mobile, server payload on web), so
/// there is NO environment branching here. The transitional [mode] is passed
/// through to sub-screens that have not yet been migrated to the repository.
class ConditionReportScreen extends StatefulWidget {
  /// Injected I/O. The entry point chooses the implementation.
  final FormRepository repo;

  /// Explicit draft id to load (mobile). Ignored when the repo is pre-loaded
  /// (web editor).
  final int? formId;

  /// Force a fresh draft instead of resuming the current one (mobile).
  final bool forceNew;

  /// Transitional: lets not-yet-migrated sub-screens know the runtime. Remove
  /// once every sub-screen is repo-driven.
  final FormEditorRuntimeMode mode;

  /// Called after a successful submit when the host needs to take over
  /// navigation (web editor: notify parent / close iframe). Null on mobile,
  /// where the screen pops itself.
  final Future<void> Function()? onCompleted;

  const ConditionReportScreen({
    super.key,
    required this.repo,
    this.formId,
    this.forceNew = false,
    this.mode = FormEditorRuntimeMode.mobileDraft,
    this.onCompleted,
  });

  @override
  State<ConditionReportScreen> createState() => _ConditionReportScreenState();
}

class _ConditionReportScreenState extends State<ConditionReportScreen> {
  final PageController _pageController = PageController();

  FormRepository get _repo => widget.repo;
  Map<String, dynamic> get _formData => _repo.formData;

  static const FormSavePolicy _autosavePolicy = FormSavePolicy(
    debounce: Duration(milliseconds: 700),
  );

  int _currentPage = 0;
  int? _formId;
  bool _isLoading = true;

  /// Question references that currently have at least one observation. Kept
  /// out of [formData] so UI-only flags never leak into the serialized payload.
  final Set<String> _questionsWithObservations = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final session = await _repo.loadOrCreateDraft(
        formType: kConditionReportFormType,
        explicitFormId: widget.formId,
        forceNew: widget.forceNew,
        allowLatestDraftFallback: true,
      );
      _formId = session.formId;
      await _loadObservations();
    } catch (e) {
      developer.log('Error loading condition report: $e');
      if (mounted) ApmFeedback.error(context, 'Error loading form: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadObservations() async {
    try {
      final observations = await _repo.getCollection('observations');
      final refs = <String>{};
      for (final obs in observations) {
        final ref = (obs['question_reference'] ?? '').toString().trim();
        if (ref.isNotEmpty) refs.add(ref);
      }
      if (!mounted) return;
      setState(() {
        _questionsWithObservations
          ..clear()
          ..addAll(refs);
      });
    } catch (e) {
      developer.log('Error loading observations: $e');
    }
  }

  bool _hasObservations(String questionRef) =>
      _questionsWithObservations.contains(questionRef);

  Future<List<Map<String, dynamic>>> _unsafeObservations() =>
      _repo.getCollection('unsafeObservations');

  @override
  void dispose() {
    _repo.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_currentPage >= 8) return;

    await _repo.flushDraft();
    await _saveForm();

    // Skip the Unsafe Situations page (7) when there are no unsafe observations.
    if (_currentPage == 6) {
      final unsafe = await _unsafeObservations();
      if (unsafe.isEmpty) {
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

  Future<void> _previousPage() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_currentPage <= 0) return;

    await _repo.flushDraft();
    await _saveForm();

    if (_currentPage == 8) {
      final unsafe = await _unsafeObservations();
      if (unsafe.isEmpty) {
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

  void _updateFormData(String key, dynamic value) {
    setState(() => _formData[key] = value);

    // Autosave. No-op on web (in-memory until completion); debounced on mobile.
    _repo.saveDraft(savePolicy: _autosavePolicy);

    if (key.endsWith('Observation') && value != null) {
      _saveObservation(key, value as Map<String, dynamic>);
    }
  }

  Future<void> _saveForm({
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) async {
    try {
      await _repo.saveDraft(savePolicy: savePolicy);
    } catch (e) {
      developer.log('Error saving form: $e');
      if (mounted) ApmFeedback.error(context, 'Error saving form: $e');
    }
  }

  Future<void> _saveObservation(
    String key,
    Map<String, dynamic> observationData,
  ) async {
    try {
      final questionRef = key.replaceAll('Observation', '');
      final notes = observationData['notes'] as String?;
      final xFiles = observationData['images'] as List<XFile>?;
      final imagePaths = xFiles?.map((x) => x.path).toList() ?? <String>[];

      final existing = (await _repo.getCollection('observations')).firstWhere(
        (o) => (o['question_reference'] ?? '').toString() == questionRef,
        orElse: () => <String, dynamic>{},
      );
      final now = DateTime.now().toUtc().toIso8601String();

      await _repo.saveCollectionItem(
        'observations',
        buildCrObservationRecord(
          id: existing['id'],
          formId: _formId ?? 0,
          questionReference: questionRef,
          notes: (notes?.isEmpty ?? true) ? null : notes,
          imagePaths: imagePaths,
          isUnsafe: existing['is_unsafe'] == 1 || existing['is_unsafe'] == true,
          existing: existing.isEmpty ? null : existing,
          nowIso: now,
        ),
      );
      await _loadObservations();
    } catch (e) {
      developer.log('Error saving observation: $e');
    }
  }

  /// Complete + submit. Mobile: mark non-active, submit, toast, pop. Web:
  /// submit (PUT), then hand back to the host via [onCompleted].
  Future<void> _completeForm() async {
    try {
      await _repo.saveDraft(status: 'pending', keepCurrentPointer: false);
      await _repo.flushDraft();
    } catch (e) {
      developer.log('Error finalising draft: $e');
    }

    String? error;
    try {
      await _repo.submit();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;

    if (widget.onCompleted != null) {
      if (error != null) {
        ApmFeedback.error(context, 'Save failed.\n$error');
        return;
      }
      await widget.onCompleted!();
      return;
    }

    if (error == null) {
      ApmFeedback.success(context, 'Form submitted.');
    } else {
      ApmFeedback.error(
        context,
        'Upload failed. Saved to My Forms for retry.\n$error',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Condition Report',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Condition Report',
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          SiteDetailsScreen(
            repo: _repo,
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          GasMeterScreen(
            repo: _repo,
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          InfrastructureOutsideScreen(
            repo: _repo,
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          SiteAssetsScreen(
            repo: _repo,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
          ),
          AssetsContinuedScreen(
            repo: _repo,
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
            onObservationsChanged: _loadObservations,
            hasObservations: _hasObservations,
          ),
          PlantRoomsListScreen(
            repo: _repo,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
          ),
          CommunalHeatingSystemScreen(
            repo: _repo,
            formData: _formData,
            onDataChanged: _updateFormData,
            onNext: _nextPage,
            onBack: _previousPage,
            formId: _formId,
          ),
          UnsafeSituationsScreen(
            repo: _repo,
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
