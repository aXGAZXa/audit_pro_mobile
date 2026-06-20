import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:audit_pro_mobile/apm/forms/shared/editor/form_draft_persistence_service.dart'
    show FormSavePolicy;
import 'heat_network_assessment_definition.dart';
import 'screens/hna_site_details_screen.dart';
import 'screens/development_details_screen.dart';
import 'screens/metering_details_screen.dart';
import 'screens/heat_generators_screen.dart';
import 'screens/dwelling_inspections_summary_screen.dart';
import 'screens/assessment_summary_screen.dart';
import 'screens/hna_summary_signature_screen.dart';
import 'screens/hna_unsafe_situations_screen.dart';

class HeatNetworkAssessmentScreen extends StatefulWidget {
  /// Injected I/O. The entry point chooses the implementation
  /// (SqliteFormRepository on mobile, WebFormRepository in the web editor) —
  /// no environment branching inside the screen.
  final FormRepository repo;
  final int? formId;
  final bool forceNew;

  /// Called after a successful submit when the host needs to take over
  /// navigation (web editor: notify parent / close iframe). Null on mobile,
  /// where the screen pops itself.
  final Future<void> Function()? onCompleted;

  const HeatNetworkAssessmentScreen({
    super.key,
    required this.repo,
    this.formId,
    this.forceNew = false,
    this.onCompleted,
  });

  @override
  State<HeatNetworkAssessmentScreen> createState() =>
      _HeatNetworkAssessmentScreenState();
}

class _HeatNetworkAssessmentScreenState
    extends State<HeatNetworkAssessmentScreen> {
  final PageController _pageController = PageController();

  FormRepository get _repo => widget.repo;

  int _currentPage = 0;
  int? _formId;
  List<String> _clients = const <String>[];

  final Map<String, dynamic> _formData = {};
  final Map<String, dynamic> _draftDoc = {};
  Map<String, dynamic> _assetsJson = <String, dynamic>{};
  Map<String, dynamic> _unsafeJson = <String, dynamic>{};
  List<Map<String, dynamic>> _observationsJson = <Map<String, dynamic>>[];
  bool _isLoading = true;
  static const FormSavePolicy _autosavePolicy = FormSavePolicy(
    debounce: Duration(milliseconds: 700),
  );

  static const String _formDataKey = 'formData';
  static const String _assetsKey = 'assets';
  static const String _unsafeKey = 'unsafe';
  static const String _observationsKey = 'observations';
  static const String _submissionSummaryKey = 'submissionSummary';
  static const String _editSessionKey = 'editSession';

  @override
  void initState() {
    super.initState();
    ApmLogger.info(
      'initState formId=${widget.formId} forceNew=${widget.forceNew}',
      category: 'HNA/Startup',
    );
    _loadOrCreateForm();
  }

  Future<void> _loadClientsBestEffort() async {
    try {
      final clients = await _repo.getClients();
      if (mounted) setState(() => _clients = clients);
    } catch (e, st) {
      ApmLogger.warning(
        'Client load failed formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
      // Best-effort: offline or not signed in should not block form usage.
    }
  }

  Future<void> _loadOrCreateForm() async {
    setState(() => _isLoading = true);

    ApmLogger.info(
      'LoadOrCreate start formId=${widget.formId} forceNew=${widget.forceNew}',
      category: 'HNA/Startup',
    );

    try {
      if (widget.formId != null) {
        ApmLogger.info(
          'Explicit form requested formId=${widget.formId}',
          category: 'HNA/Startup',
        );
      }

      final session = await _repo.loadOrCreateDraft(
        formType: kHeatNetworkAssessmentFormType,
        explicitFormId: widget.formId,
        forceNew: widget.forceNew,
        allowLatestDraftFallback: false,
      );
      _formId = session.formId;

      // The document lives in repo.formData (JSON-native). Hydrate the working
      // copies the sub-screens read; persistence + serialization stay in the repo.
      _hydrateFromDraftDoc(Map<String, dynamic>.from(_repo.formData));

      ApmLogger.info(
        'Loaded draft session formId=$_formId status=${session.status}',
        category: 'HNA/Startup',
      );
      if (mounted) setState(() => _isLoading = false);
      await _loadClientsBestEffort();
    } catch (e, st) {
      ApmLogger.warning(
        'Error loading form: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    return value;
  }

  void _updateFormData(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
      _draftDoc[_formDataKey] = _formData;
    });
    _saveForm(status: 'draft', savePolicy: _autosavePolicy); // Autosave
  }

  void _updateAssets(Map<String, dynamic> nextAssets) {
    setState(() {
      _assetsJson = Map<String, dynamic>.from(nextAssets);
      _draftDoc[_assetsKey] = _assetsJson;
    });
    _saveForm(status: 'draft', savePolicy: _autosavePolicy);
  }

  void _updateUnsafe(Map<String, dynamic> nextUnsafe) {
    setState(() {
      _unsafeJson = Map<String, dynamic>.from(nextUnsafe);
      _draftDoc[_unsafeKey] = _unsafeJson;
    });
    _saveForm(status: 'draft', savePolicy: _autosavePolicy);
  }

  void _updateObservations(List<Map<String, dynamic>> nextObservations) {
    setState(() {
      _observationsJson = nextObservations
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
      _draftDoc[_observationsKey] = _observationsJson;

      _reconcileUnsafeFromObservations();
    });
    _saveForm(status: 'draft', savePolicy: _autosavePolicy);
  }

  bool _isUnsafeObservation(Map<String, dynamic> observation) {
    final raw =
        observation['is_unsafe'] ??
        observation['isUnsafe'] ??
        observation['isUnsafeObservation'];
    return raw == true || raw == 1;
  }

  void _reconcileUnsafeFromObservations() {
    final unsafeFromObs = <Map<String, dynamic>>[];
    for (final o in _observationsJson) {
      if (!_isUnsafeObservation(o)) continue;

      final id = (o['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      // Keep both camelCase and legacy snake_case keys for older screens.
      unsafeFromObs.add({
        ...o,
        'question_reference': o['question_reference'] ?? o['questionReference'],
        'question_text': o['question_text'] ?? o['questionText'],
        'section_name': o['section_name'] ?? o['sectionName'],
        'asset_id': o['asset_id'] ?? o['assetId'],
        'asset_type': o['asset_type'] ?? o['assetType'],
        'asset_make_model': o['asset_make_model'] ?? o['assetMakeModel'],
      });
    }

    // Only overwrite when we have an authoritative source from the main
    // observations list; otherwise preserve any existing legacy unsafe data.
    if (unsafeFromObs.isNotEmpty) {
      _unsafeJson['unsafeObservations'] = unsafeFromObs;
    } else {
      _unsafeJson['unsafeObservations'] =
          (_unsafeJson['unsafeObservations'] is List)
          ? List<dynamic>.from(_unsafeJson['unsafeObservations'] as List)
          : <dynamic>[];
    }
    _unsafeJson['unsafeReports'] = (_unsafeJson['unsafeReports'] is List)
        ? List<dynamic>.from(_unsafeJson['unsafeReports'] as List)
        : <dynamic>[];
    _unsafeJson['unreportedUnsafeObservations'] =
        (_unsafeJson['unreportedUnsafeObservations'] is List)
        ? List<dynamic>.from(
            _unsafeJson['unreportedUnsafeObservations'] as List,
          )
        : <dynamic>[];

    _draftDoc[_unsafeKey] = _unsafeJson;
  }

  bool _shouldShowUnsafeSituations() {
    final unsafeObs = _unsafeJson['unsafeObservations'];
    if (unsafeObs is List && unsafeObs.isNotEmpty) return true;

    final unsafeReports = _unsafeJson['unsafeReports'];
    if (unsafeReports is List && unsafeReports.isNotEmpty) return true;

    final unreported = _unsafeJson['unreportedUnsafeObservations'];
    if (unreported is List && unreported.isNotEmpty) return true;

    // Primary signal: any observation flagged unsafe.
    for (final o in _observationsJson) {
      if (_isUnsafeObservation(o)) return true;
    }
    return false;
  }

  Future<void> _saveForm({
    String status = 'draft',
    FormSavePolicy savePolicy = const FormSavePolicy.immediate(),
  }) async {
    if (_formId == null) return;
    try {
      // Single in-memory document: repo.formData is the one source of truth and
      // this screen is its only writer (sub-screens flow back through the
      // _update* callbacks), so there is no stale-overwrite to guard against.
      // Start from the current document (preserves meta like submissionSummary /
      // editSession) and overlay the working sections.
      final docToSave = Map<String, dynamic>.from(_repo.formData);

      // Carry any in-memory non-managed meta keys (e.g. edit session info).
      for (final entry in _draftDoc.entries) {
        final key = entry.key.toString();
        if (key == _formDataKey ||
            key == _assetsKey ||
            key == _unsafeKey ||
            key == _observationsKey) {
          continue;
        }
        docToSave[key] = entry.value;
      }

      docToSave[_formDataKey] = _formData;
      docToSave[_assetsKey] = _assetsJson;
      docToSave[_unsafeKey] = _unsafeJson;
      docToSave[_observationsKey] = _observationsJson;

      // Keep the document JSON-native (dates as strings etc.) so the web submit
      // path (buildFromFormSnapshot -> jsonEncode) never sees a DateTime.
      final serialized = Map<String, dynamic>.from(
        _convertToSerializable(docToSave) as Map,
      );
      _repo.formData
        ..clear()
        ..addAll(serialized);

      await _repo.saveDraft(
        status: status,
        keepCurrentPointer: status == 'draft',
        savePolicy: savePolicy,
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Error saving form formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
    }
  }

  List<Widget> _buildPages() {
    final isNetwork = [
      'District Heat Network',
      'Communal Heat Network',
    ].contains(_formData['meetsHeatNetworkDefinition']);

    final shouldShowGenerators =
        _formData['meetsHeatNetworkDefinition'] != 'In-Flat Generation' &&
        _formData['meetsHeatNetworkDefinition'] != null;

    final shouldShowUnsafe = _shouldShowUnsafeSituations();

    return [
      HNASiteDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        formId: _formId,
        clients: _clients,
      ),
      DevelopmentDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
      ),
      if (isNetwork)
        MeteringDetailsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: _nextPage,
          onBack: _previousPage,
          formId: _formId,
          assetsJson: _assetsJson,
          onAssetsChanged: _updateAssets,
          observationsJson: _observationsJson,
          onObservationsChanged: _updateObservations,
        ),
      if (shouldShowGenerators)
        HeatGeneratorsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: _nextPage,
          onBack: _previousPage,
          formId: _formId,
          assetsJson: _assetsJson,
          onAssetsChanged: _updateAssets,
          observationsJson: _observationsJson,
          onObservationsChanged: _updateObservations,
        ),
      DwellingInspectionsSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        assetsJson: _assetsJson,
        onAssetsChanged: _updateAssets,
        observationsJson: _observationsJson,
        onObservationsChanged: _updateObservations,
      ),
      if (shouldShowUnsafe)
        HNAUnsafeSituationsScreen(
          formData: _formData,
          unsafeJson: _unsafeJson,
          onUnsafeChanged: _updateUnsafe,
          onNext: _nextPage,
          onBack: _previousPage,
        ),
      AssessmentSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
        assetsJson: _assetsJson,
      ),
      HNASummarySignatureScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onBack: _previousPage,
        onComplete: () {
          _completeAndSubmit();
        },
        formId: _formId,
      ),
    ];
  }

  void _hydrateFromDraftDoc(Map<String, dynamic> converted) {
    _draftDoc
      ..clear()
      ..addAll(converted);

    final rawFormData = _draftDoc[_formDataKey];
    final rawAssets = _draftDoc[_assetsKey];

    _formData.clear();

    if (rawFormData is Map) {
      _formData.addAll(Map<String, dynamic>.from(rawFormData));
    } else {
      // Legacy draft shape: form fields at the root.
      // Preserve known meta keys at the root, but wrap the rest under formData.
      final legacy = Map<String, dynamic>.from(_draftDoc);
      final meta = <String, dynamic>{};
      for (final k in [_submissionSummaryKey, _editSessionKey]) {
        if (legacy.containsKey(k)) {
          meta[k] = legacy.remove(k);
        }
      }

      // If an old draft already had an assets blob at the root, keep it.
      Map<String, dynamic> assets = <String, dynamic>{};
      final legacyAssets = legacy.remove(_assetsKey);
      if (legacyAssets is Map) {
        assets = Map<String, dynamic>.from(legacyAssets);
      }

      _formData.addAll(legacy);
      _draftDoc
        ..clear()
        ..addAll(meta)
        ..[_formDataKey] = _formData
        ..[_assetsKey] = assets;
    }

    if (rawAssets is Map) {
      _assetsJson = Map<String, dynamic>.from(rawAssets);
    } else {
      final existing = _draftDoc[_assetsKey];
      _assetsJson = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
    }

    final rawUnsafe = _draftDoc[_unsafeKey];
    _unsafeJson = rawUnsafe is Map
        ? Map<String, dynamic>.from(rawUnsafe)
        : <String, dynamic>{};

    // Ensure minimum shapes.
    _unsafeJson['unsafeObservations'] =
        (_unsafeJson['unsafeObservations'] is List)
        ? List<dynamic>.from(_unsafeJson['unsafeObservations'] as List)
        : <dynamic>[];
    _unsafeJson['unsafeReports'] = (_unsafeJson['unsafeReports'] is List)
        ? List<dynamic>.from(_unsafeJson['unsafeReports'] as List)
        : <dynamic>[];
    _unsafeJson['unreportedUnsafeObservations'] =
        (_unsafeJson['unreportedUnsafeObservations'] is List)
        ? List<dynamic>.from(
            _unsafeJson['unreportedUnsafeObservations'] as List,
          )
        : <dynamic>[];

    final rawObservations = _draftDoc[_observationsKey];
    final obsList = rawObservations is List
        ? rawObservations
        : const <dynamic>[];
    _observationsJson = obsList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);
    _draftDoc[_observationsKey] = _observationsJson;

    _reconcileUnsafeFromObservations();

    // Ensure minimum shape.
    _assetsJson.putIfAbsent('heatMeters', () => <dynamic>[]);
    _draftDoc[_assetsKey] = _assetsJson;
    _draftDoc[_unsafeKey] = _unsafeJson;
    _draftDoc[_formDataKey] = _formData;
  }

  Future<void> _completeAndSubmit() async {
    ApmLogger.info(
      'Complete+Submit start formId=$_formId',
      category: 'HNA/Submit',
    );

    // Mark pending + drop the in-progress-draft pointer (stays in My Forms for
    // retry), flush, then submit through the injected repository. Mobile POSTs
    // via the HNA submitter; web PUTs via the editor API.
    await _saveForm(status: 'pending');
    await _repo.flushDraft();

    String? error;
    try {
      await _repo.submit();
    } catch (e, st) {
      error = e.toString();
      ApmLogger.warning(
        'Complete+Submit failed formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Submit',
        error: e,
        stackTrace: st,
      );
    }

    if (!mounted) return;

    // Web host takes over navigation (notify parent / close iframe).
    if (widget.onCompleted != null) {
      if (error != null) {
        ApmFeedback.error(context, 'Save failed.\n$error');
        return;
      }
      await widget.onCompleted!();
      return;
    }

    if (error == null) {
      ApmLogger.info(
        'Complete+Submit success formId=$_formId',
        category: 'HNA/Submit',
      );
      ApmFeedback.success(context, 'Form submitted.');
    } else {
      ApmFeedback.error(
        context,
        'Upload failed. Saved to My Forms for retry.\n$error',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _previousPage() async {
    await _saveForm();
    await _repo.flushDraft();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() async {
    final pages = _buildPages();

    if (_currentPage < pages.length - 1) {
      await _saveForm();
      await _repo.flushDraft();

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete ?
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _repo.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Heat Network Assessment',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = _buildPages();

    return AppScaffold(
      title: 'Heat Network Assessment',
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: pages,
      ),
    );
  }
}
