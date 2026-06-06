import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/app_scaffold.dart';
import 'screens/assessment_summary_screen.dart';
import 'screens/development_details_screen.dart';
import 'screens/dwelling_inspections_summary_screen.dart';
import 'screens/heat_generators_screen.dart';
import 'screens/hna_site_details_screen.dart';
import 'screens/hna_summary_signature_screen.dart';
import 'screens/hna_unsafe_situations_screen.dart';
import 'screens/metering_details_screen.dart';
import 'services/hna_derived_metrics_calculator.dart';
import 'services/hna_pdf_derived_calculator.dart';
import 'services/hna_pdf_model_builder.dart';
import 'services/hna_submission_payload_builder.dart';
import 'services/hna_web_editor_attachment_context.dart';
import 'services/hna_web_editor_service.dart';
import 'services/web_editor_return.dart';
import 'hna_web_editor_complete_screen.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';

import 'package:uuid/uuid.dart';

class HnaWebEditorFormScreen extends StatefulWidget {
  const HnaWebEditorFormScreen({
    super.key,
    required this.ticket,
    required this.submissionId,
    required this.submittedAtUtc,
    required this.schemaVersion,
    required this.originalPayload,
    required this.initialFormData,
    required this.clients,
    required this.service,
    this.returnUrl,
  });

  final String ticket;
  final String submissionId;
  final DateTime? submittedAtUtc;
  final int? schemaVersion;

  /// Full payload from the portal submission (the thing stored as PayloadJson).
  /// We preserve everything we don't edit so we don't accidentally wipe assets,
  /// observations, etc.
  final Map<String, dynamic> originalPayload;

  /// The editable formData map (typically payload['hna']['formData']).
  final Map<String, dynamic> initialFormData;

  /// Tenant-scoped client names fetched via the editor ticket.
  final List<String> clients;

  final FormWebEditorService service;

  /// Optional URL to return to after completing the edit.
  ///
  /// On web this is typically populated from `returnUrl` query param or browser
  /// referrer and persisted per ticket.
  final String? returnUrl;

  @override
  State<HnaWebEditorFormScreen> createState() => _HnaWebEditorFormScreenState();
}

class _HnaWebEditorFormScreenState extends State<HnaWebEditorFormScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _saving = false;
  bool _dirty = false;
  bool _needsSchemaUpgrade = false;
  bool _needsDerivedMetricsUpgrade = false;
  String? _lastSavedPayloadJson;

  late final Map<String, dynamic> _formData = Map<String, dynamic>.from(
    widget.initialFormData,
  );

  late final Map<String, dynamic> _assetsJson = _cloneAssetsFromPayload();
  late final Map<String, dynamic> _unsafeJson = _cloneUnsafeFromPayload();
  late List<Map<String, dynamic>> _observationsJson =
      _cloneObservationsFromPayload();

  Map<String, dynamic> _cloneAssetsFromPayload() {
    final rawHna = widget.originalPayload['hna'];
    if (rawHna is! Map) return <String, dynamic>{};
    final hna = Map<String, dynamic>.from(rawHna);
    final rawAssets = hna['assets'];
    if (rawAssets is Map) {
      return Map<String, dynamic>.from(rawAssets);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _cloneUnsafeFromPayload() {
    final rawHna = widget.originalPayload['hna'];
    if (rawHna is! Map) return <String, dynamic>{};
    final hna = Map<String, dynamic>.from(rawHna);
    final rawUnsafe = hna['unsafe'];
    if (rawUnsafe is Map) {
      final out = Map<String, dynamic>.from(rawUnsafe);
      out['unsafeObservations'] = out['unsafeObservations'] is List
          ? out['unsafeObservations']
          : [];
      out['unsafeReports'] = out['unsafeReports'] is List
          ? out['unsafeReports']
          : [];
      out['unreportedUnsafeObservations'] =
          out['unreportedUnsafeObservations'] is List
          ? out['unreportedUnsafeObservations']
          : [];
      return out;
    }
    return <String, dynamic>{
      'unsafeObservations': <dynamic>[],
      'unsafeReports': <dynamic>[],
      'unreportedUnsafeObservations': <dynamic>[],
    };
  }

  List<Map<String, dynamic>> _cloneObservationsFromPayload() {
    final rawHna = widget.originalPayload['hna'];
    if (rawHna is! Map) return <Map<String, dynamic>>[];
    final hna = Map<String, dynamic>.from(rawHna);
    final rawObservations = hna['observations'];
    if (rawObservations is List) {
      return rawObservations
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  void _updateObservations(List<Map<String, dynamic>> nextObservations) {
    setState(() {
      _observationsJson = nextObservations
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
      _dirty = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _needsSchemaUpgrade =
        (widget.schemaVersion ?? 0) <
        HnaSubmissionPayloadBuilder.payloadSchemaVersion;

    final existingDerived = widget.initialFormData['derivedMetrics'];
    final existingDerivedSchemaRaw = existingDerived is Map
        ? existingDerived['schemaVersion']
        : null;
    final existingDerivedSchema = existingDerivedSchemaRaw is int
        ? existingDerivedSchemaRaw
        : int.tryParse((existingDerivedSchemaRaw ?? '').toString());
    _needsDerivedMetricsUpgrade =
        (existingDerivedSchema ?? 0) <
        HnaDerivedMetricsCalculator.schemaVersion;

    // Treat the initial payload as already-saved so users can navigate without
    // forcing an immediate PUT when nothing has changed.
    _lastSavedPayloadJson = jsonEncode(
      _makeJsonEncodable(_buildUpdatedPayload(recomputeDerivedMetrics: false)),
    );
    _dirty = false;
  }

  dynamic _makeJsonEncodable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is String || value is bool) return value;
    if (value is List) return value.map(_makeJsonEncodable).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _makeJsonEncodable(v)));
    }
    // Last resort: stringify unknown objects rather than crashing saves.
    return value.toString();
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
    if (a is DateTime && b is String) {
      final parsed = DateTime.tryParse(b);
      return parsed != null && a.isAtSameMomentAs(parsed);
    }
    if (a is String && b is DateTime) {
      final parsed = DateTime.tryParse(a);
      return parsed != null && b.isAtSameMomentAs(parsed);
    }
    return false;
  }

  void _updateFormData(String key, dynamic value) {
    final existing = _formData[key];
    if (_valuesEqual(existing, value)) return;
    setState(() {
      _formData[key] = value;
      _dirty = true;
    });
  }

  void _updateAssets(Map<String, dynamic> nextAssets) {
    setState(() {
      _assetsJson
        ..clear()
        ..addAll(nextAssets);
      _dirty = true;
    });
  }

  void _updateUnsafe(Map<String, dynamic> nextUnsafe) {
    setState(() {
      _unsafeJson
        ..clear()
        ..addAll(nextUnsafe);
      _dirty = true;
    });
  }

  Future<bool> _saveIfDirty({
    required bool showSuccessToast,
    bool generatePdf = false,
    bool forceRecompute = false,
  }) async {
    if (_saving) return false;
    final shouldRecompute =
        forceRecompute ||
        _dirty ||
        _needsSchemaUpgrade ||
        _needsDerivedMetricsUpgrade;

    if (!shouldRecompute && !generatePdf) {
      return true;
    }

    final updatedPayload = _buildUpdatedPayload(
      recomputeDerivedMetrics: shouldRecompute,
    );
    final payloadJson = jsonEncode(_makeJsonEncodable(updatedPayload));

    if (!shouldRecompute && _lastSavedPayloadJson == payloadJson) {
      setState(() => _dirty = false);
      return true;
    }

    setState(() => _saving = true);

    try {
      await widget.service.updateSubmission(
        ticket: widget.ticket,
        payloadJson: payloadJson,
        generatePdf: generatePdf,
      );

      // Attachments are add-only; committing just clears local pending state.
      FormWebEditorAttachmentContext.instance.commitPending();

      if (!mounted) return false;
      _lastSavedPayloadJson = payloadJson;
      setState(() {
        _dirty = false;
        _needsSchemaUpgrade = false;
        _needsDerivedMetricsUpgrade = false;
      });

      if (showSuccessToast) {
        ApmFeedback.success(context, 'Saved');
      }

      return true;
    } catch (e) {
      if (!mounted) return false;
      ApmFeedback.error(context, 'Save failed: $e');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _autoSaveAndThen(VoidCallback navigate) {
    _saveIfDirty(showSuccessToast: false, generatePdf: kIsWeb).then((ok) {
      if (!mounted) return;
      if (!ok) return;
      navigate();
    });
  }

  bool _isNetwork() {
    return const [
      'District Heat Network',
      'Communal Heat Network',
    ].contains(_formData['meetsHeatNetworkDefinition']);
  }

  bool _shouldShowGenerators() {
    return _formData['meetsHeatNetworkDefinition'] != 'In-Flat Generation' &&
        _formData['meetsHeatNetworkDefinition'] != null;
  }

  bool _shouldShowUnsafeSituations() {
    final unsafeObs = _unsafeJson['unsafeObservations'];
    if (unsafeObs is List && unsafeObs.isNotEmpty) return true;
    final unsafeReports = _unsafeJson['unsafeReports'];
    if (unsafeReports is List && unsafeReports.isNotEmpty) return true;
    final unreported = _unsafeJson['unreportedUnsafeObservations'];
    if (unreported is List && unreported.isNotEmpty) return true;
    return false;
  }

  List<Widget> _buildPages() {
    final isNetwork = _isNetwork();
    final shouldShowGenerators = _shouldShowGenerators();
    final shouldShowUnsafe = _shouldShowUnsafeSituations();

    return [
      HNASiteDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: () => _autoSaveAndThen(_nextPage),
        formId: null,
        clientsSyncNonce: 0,
        clientsOverride: widget.clients,
      ),
      DevelopmentDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: () => _autoSaveAndThen(_nextPage),
        onBack: () => _autoSaveAndThen(_previousPage),
        formId: null,
      ),
      if (isNetwork)
        MeteringDetailsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: () => _autoSaveAndThen(_nextPage),
          onBack: () => _autoSaveAndThen(_previousPage),
          formId: null,
          assetsJson: _assetsJson,
          onAssetsChanged: _updateAssets,
          observationsJson: _observationsJson,
          onObservationsChanged: _updateObservations,
        ),
      if (shouldShowGenerators)
        HeatGeneratorsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: () => _autoSaveAndThen(_nextPage),
          onBack: () => _autoSaveAndThen(_previousPage),
          formId: null,
          assetsJson: _assetsJson,
          onAssetsChanged: _updateAssets,
          observationsJson: _observationsJson,
          onObservationsChanged: _updateObservations,
        ),
      DwellingInspectionsSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: () => _autoSaveAndThen(_nextPage),
        onBack: () => _autoSaveAndThen(_previousPage),
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
          onNext: () => _autoSaveAndThen(_nextPage),
          onBack: () => _autoSaveAndThen(_previousPage),
        ),
      AssessmentSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: () => _autoSaveAndThen(_nextPage),
        onBack: () => _autoSaveAndThen(_previousPage),
        formId: null,
      ),
      HNASummarySignatureScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onBack: () => _autoSaveAndThen(_previousPage),
        onComplete: _saveAndExit,
        formId: null,
      ),
    ];
  }

  void _previousPage() {
    if (_currentPage <= 0) return;

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    final pages = _buildPages();

    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    Navigator.of(context).pop();
  }

  Map<String, dynamic> _buildUpdatedPayload({
    required bool recomputeDerivedMetrics,
  }) {
    final out = Map<String, dynamic>.from(widget.originalPayload);

    Map<String, dynamic> hna;
    final rawHna = out['hna'];
    if (rawHna is Map) {
      hna = Map<String, dynamic>.from(rawHna);
    } else {
      hna = <String, dynamic>{};
    }

    final formDataOut = Map<String, dynamic>.from(_formData);

    // Persist any asset edits made in the web editor (meters, etc.).
    hna['assets'] = Map<String, dynamic>.from(_assetsJson);
    hna['unsafe'] = Map<String, dynamic>.from(_unsafeJson);
    hna['observations'] = _observationsJson
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final rawForm = out['form'];
    final form = rawForm is Map ? Map<String, dynamic>.from(rawForm) : null;
    final formId = form == null
        ? 0
        : int.tryParse((form['id'] ?? '0').toString()) ?? 0;

    hna['attachments'] = FormWebEditorAttachmentContext.instance.buildManifest(
      formId: formId,
      formData: formDataOut,
      assetsJson: Map<String, dynamic>.from(_assetsJson),
      observationsJson: _observationsJson
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      unsafeJson: Map<String, dynamic>.from(_unsafeJson),
    );

    _ensureV4Envelope(out: out, hna: hna, formData: formDataOut);

    if (recomputeDerivedMetrics) {
      final assets = hna['assets'];
      final observations = hna['observations'];
      final unsafe = hna['unsafe'];
      final attachments = hna['attachments'];
      final summary = hna['summary'];

      final existingDerived = formDataOut['derivedMetrics'];
      final existingMethodology = existingDerived is Map
          ? existingDerived['methodologyVersion']
          : null;
      final methodologyVersion = (existingMethodology ?? 'v1').toString();

      formDataOut['derivedMetrics'] =
          HnaDerivedMetricsCalculator.computeFromPayload(
            formData: formDataOut,
            assetsJson: assets is Map
                ? Map<String, dynamic>.from(assets)
                : null,
            observationsJson: observations is List
                ? List<dynamic>.from(observations)
                : null,
            unsafeJson: unsafe is Map
                ? Map<String, dynamic>.from(unsafe)
                : null,
            methodologyVersion: methodologyVersion,
          );

      if (assets is Map) {
        final pdfDerivedExisting = formDataOut['pdfDerived'];
        final pdfDerivedMethodology = pdfDerivedExisting is Map
            ? pdfDerivedExisting['methodologyVersion']
            : null;
        final pdfMethodologyVersion =
            (pdfDerivedMethodology ?? methodologyVersion).toString();

        formDataOut['pdfDerived'] = HnaPdfDerivedCalculator.computeFromPayload(
          formData: formDataOut,
          assetsJson: Map<String, dynamic>.from(assets),
          observationsJson: observations is List
              ? List<dynamic>.from(observations)
              : null,
          methodologyVersion: pdfMethodologyVersion,
        );
      }

      final reportNumber = _tryReadReportNumber(
        summary: summary,
        existingPdfModel: hna['pdfModel'],
      );

      if (reportNumber != null && reportNumber.trim().isNotEmpty) {
        final assetsMap = assets is Map
            ? Map<String, dynamic>.from(assets)
            : null;
        final unsafeObservationsJson = _tryReadMapList(
          unsafe is Map ? unsafe['unsafeObservations'] : null,
        );
        final unsafeReportsJson = _tryReadMapList(
          unsafe is Map ? unsafe['unsafeReports'] : null,
        );
        final attachmentsJson = _tryReadMapList(attachments);
        final observationsJson = _tryReadMapList(observations);

        if (assetsMap != null) {
          hna['pdfModel'] = HnaPdfModelBuilder.build(
            formId: 0,
            reportNumber: reportNumber,
            formData: formDataOut,
            assetsJson: assetsMap,
            observationsJson: observationsJson,
            unsafeObservationsJson: unsafeObservationsJson,
            unsafeReportsJson: unsafeReportsJson,
            attachments: attachmentsJson,
          );
        }
      }
    }

    hna['formData'] = formDataOut;
    out['hna'] = hna;

    return out;
  }

  void _ensureV4Envelope({
    required Map<String, dynamic> out,
    required Map<String, dynamic> hna,
    required Map<String, dynamic> formData,
  }) {
    // Always emit the latest payload schema from the web editor.
    out['payloadSchemaVersion'] =
        HnaSubmissionPayloadBuilder.payloadSchemaVersion;

    final rawForm = out['form'];
    final form = rawForm is Map
        ? Map<String, dynamic>.from(rawForm)
        : <String, dynamic>{};

    final rawSummary = hna['summary'];
    final summary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    var formUuid = (form['uuid'] ?? '').toString().trim();
    if (formUuid.isEmpty) {
      final fromSummary = (summary['formUuid'] ?? '').toString().trim();
      formUuid = fromSummary.isNotEmpty ? fromSummary : const Uuid().v4();
      form['uuid'] = formUuid;
    }

    final submittedAt = (widget.submittedAtUtc ?? DateTime.now()).toUtc();
    final existingFriendlyRef = (summary['friendlyRef'] ?? '')
        .toString()
        .trim();
    final friendlyRef = existingFriendlyRef.isNotEmpty
        ? existingFriendlyRef
        : HnaSubmissionPayloadBuilder.buildFriendlyRef(
            submittedAt: submittedAt,
            formUuid: formUuid,
          );

    // Keep summary aligned with edited formData so downstream reporting has
    // consistent scalar fields.
    summary['assessorName'] =
        (formData['auditorName'] ?? formData['assessorName'] ?? '').toString();
    summary['clientName'] = (formData['client'] ?? '').toString();
    summary['auditDate'] = (formData['auditDate'] ?? '').toString();
    summary['submittedAt'] =
        (summary['submittedAt'] ?? submittedAt.toIso8601String()).toString();
    summary['friendlyRef'] = friendlyRef;
    summary['formUuid'] = formUuid;
    summary['formId'] = form['id'] ?? summary['formId'] ?? 0;

    hna['summary'] = summary;
    out['form'] = form;
  }

  String? _tryReadReportNumber({
    required dynamic summary,
    required dynamic existingPdfModel,
  }) {
    if (summary is Map) {
      final friendlyRef = (summary['friendlyRef'] ?? '').toString().trim();
      if (friendlyRef.isNotEmpty) return friendlyRef;
    }

    if (existingPdfModel is Map) {
      final reportNumber = (existingPdfModel['ReportNumber'] ?? '')
          .toString()
          .trim();
      if (reportNumber.isNotEmpty) return reportNumber;
    }

    return null;
  }

  List<Map<String, dynamic>> _tryReadMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  Future<void> _saveAndExit() async {
    final ok = await _saveIfDirty(
      showSuccessToast: true,
      generatePdf: kIsWeb,
      forceRecompute: true,
    );
    if (!ok) return;
    if (!mounted) return;

    if (kIsWeb) {
      // Notify the parent portal that the edit has completed.
      // Navigation is handled by the host; we keep the editor open and show
      // an explicit success screen so users get clear feedback.
      WebEditorReturn.notifyParentComplete(
        ticket: widget.ticket,
        returnUrl: widget.returnUrl,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna-web-editor-complete'),
          builder: (_) => const HnaWebEditorCompleteScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return AppScaffold(
      title: 'Heat Network Assessment',
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: pages,
          ),
          if (_saving)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
