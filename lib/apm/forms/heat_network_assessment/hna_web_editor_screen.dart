import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../condition_report/condition_report_definition.dart';
import '../condition_report/condition_report_screen.dart';
import '../condition_report/services/cr_submission_payload_builder.dart';
import '../shared/editor/form_editor_contract.dart';
import 'heat_network_assessment_definition.dart';
import '../../services/portal_api_client.dart';
import 'hna_web_editor_form_screen.dart';
import 'services/hna_web_editor_attachment_context.dart';
import 'services/hna_derived_metrics_calculator.dart';
import 'services/hna_pdf_derived_calculator.dart';
import 'services/hna_pdf_model_builder.dart';
import 'services/hna_submission_payload_builder.dart';
import 'services/hna_web_editor_service.dart';
import 'services/web_editor_return.dart';

class ApmWebEditorScreen extends StatefulWidget {
  const ApmWebEditorScreen({
    super.key,
    required this.ticket,
    this.returnUrl,
    this.mode,
  });

  final String ticket;
  final String? returnUrl;
  final String? mode;

  @override
  State<ApmWebEditorScreen> createState() => _ApmWebEditorScreenState();
}

class _ApmWebEditorScreenState extends State<ApmWebEditorScreen> {
  static const String _buildId = String.fromEnvironment(
    'APM_WEB_EDITOR_BUILD_ID',
    defaultValue: 'unknown-build',
  );
  static const String _definesSource = String.fromEnvironment(
    'APM_DEFINES_SOURCE',
    defaultValue: 'unknown-source',
  );

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _crOriginalPayload;

  late final FormWebEditorService _service;
  String? _returnUrl;

  bool get _isAutoResubmit => (widget.mode ?? '').trim() == 'auto-resubmit';

  @override
  void initState() {
    super.initState();
    final baseUrl = kIsWeb ? Uri.base.origin : '';
    _service = FormWebEditorService(
      apiClient: PortalApiClient(baseUrl: baseUrl),
    );

    _returnUrl = _resolveReturnUrl();
    if (kIsWeb && _returnUrl != null) {
      WebEditorReturn.setLocalStorage(
        _returnStorageKey(widget.ticket),
        _returnUrl!,
      );
    }

    _logDiag('init', {
      'ticket': _ticketPreview(widget.ticket),
      'buildId': _buildId,
      'source': _definesSource,
      'mode': widget.mode ?? '',
      'returnUrl': _returnUrl ?? '',
      'origin': kIsWeb ? Uri.base.origin : '',
    });

    _load();
  }

  String _returnStorageKey(String ticket) => 'hnaEditor:returnUrl:$ticket';

  String? _resolveReturnUrl() {
    final fromParam = widget.returnUrl?.trim();
    if (fromParam != null &&
        fromParam.isNotEmpty &&
        _isAllowedReturnUrl(fromParam)) {
      return fromParam;
    }

    if (kIsWeb) {
      final stored = WebEditorReturn.getLocalStorage(
        _returnStorageKey(widget.ticket),
      );
      if (stored != null &&
          stored.trim().isNotEmpty &&
          _isAllowedReturnUrl(stored)) {
        return stored.trim();
      }

      final referrer = WebEditorReturn.getReferrer();
      if (referrer != null && _isAllowedReturnUrl(referrer)) {
        return referrer;
      }
    }

    return null;
  }

  bool _isAllowedReturnUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Allow relative navigation.
      if (!uri.hasScheme && url.startsWith('/')) return true;

      if (uri.scheme != 'http' && uri.scheme != 'https') return false;

      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') return true;

      // Allow our production domains.
      if (host.endsWith('.audit-pro.co.uk') || host == 'audit-pro.co.uk') {
        return true;
      }

      // As a fallback, allow same-origin.
      final origin = Uri.base.origin;
      return uri.origin == origin;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _service.getSession(ticket: widget.ticket);
      final submission = await _service.getSubmission(ticket: widget.ticket);

      final ticketFormType = _resolveSessionFormType(session);
      _logDiag('session-loaded', {
        'ticket': _ticketPreview(widget.ticket),
        'formType': ticketFormType,
        'submissionId':
            (submission['submissionId'] ?? submission['SubmissionId'] ?? '')
                .toString(),
      });

      if (ticketFormType == kConditionReportFormType) {
        _logDiag('route-condition-report', {
          'ticket': _ticketPreview(widget.ticket),
        });

        final payloadJson =
            (submission['payloadJson'] ?? submission['PayloadJson'] ?? '')
                .toString()
                .trim();
        if (payloadJson.isEmpty) {
          throw PortalApiException('Submission payload is empty.');
        }

        final decoded = jsonDecode(payloadJson);
        if (decoded is! Map) {
          throw PortalApiException('Submission payload is not a JSON object.');
        }

        _crOriginalPayload = Map<String, dynamic>.from(decoded);

        final payload = Map<String, dynamic>.from(decoded);
        final conditionReportRaw = payload['conditionReport'];
        if (conditionReportRaw is! Map) {
          final formType = _resolveSessionFormType(_session ?? const {});
          throw PortalApiException(
            _withDiag(
              'Condition report payload is missing. formType="$formType" payloadKeys=${payload.keys.join(',')}',
            ),
          );
        }

        final formData = Map<String, dynamic>.from(conditionReportRaw);
        final submissionId =
            (submission['submissionId'] ?? submission['SubmissionId'] ?? '')
                .toString()
                .trim();

        final attachmentsRaw = formData['attachments'];
        final attachments = <Map<String, dynamic>>[];
        if (attachmentsRaw is List) {
          for (final item in attachmentsRaw) {
            if (item is Map) {
              attachments.add(Map<String, dynamic>.from(item));
            }
          }
        }

        FormWebEditorAttachmentContext.instance.configure(
          service: _service,
          ticket: widget.ticket,
          submissionId: submissionId,
          initialAttachments: attachments,
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/cr-web-editor'),
            builder: (_) => ConditionReportScreen(
              mode: FormEditorRuntimeMode.webEditor,
              initialFormData: formData,
              onCompleteForm: _completeConditionReportWebEditor,
            ),
          ),
        );
        return;
      }

      if (ticketFormType.isNotEmpty &&
          ticketFormType != kHeatNetworkAssessmentFormType) {
        throw PortalApiException(
          'Unsupported editor form type "$ticketFormType".',
        );
      }

      _logDiag('route-hna', {'ticket': _ticketPreview(widget.ticket)});

      final clients = _isAutoResubmit
          ? const <String>[]
          : await _service.getClients(ticket: widget.ticket);

      final payloadJson =
          (submission['payloadJson'] ?? submission['PayloadJson'] ?? '')
              .toString()
              .trim();
      if (payloadJson.isEmpty) {
        throw PortalApiException('Submission payload is empty.');
      }

      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        throw PortalApiException('Submission payload is not a JSON object.');
      }
      final payload = Map<String, dynamic>.from(decoded);

      final submissionId =
          (submission['submissionId'] ?? submission['SubmissionId'] ?? '')
              .toString()
              .trim();

      final hnaRaw = payload['hna'];
      final hna = hnaRaw is Map
          ? Map<String, dynamic>.from(hnaRaw)
          : <String, dynamic>{};
      final formDataRaw = hna['formData'];
      final formData = formDataRaw is Map
          ? Map<String, dynamic>.from(formDataRaw)
          : <String, dynamic>{};

      final attachmentsRaw = hna['attachments'];
      final attachments = <Map<String, dynamic>>[];
      if (attachmentsRaw is List) {
        for (final item in attachmentsRaw) {
          if (item is Map) {
            attachments.add(Map<String, dynamic>.from(item));
          }
        }
      }

      FormWebEditorAttachmentContext.instance.configure(
        service: _service,
        ticket: widget.ticket,
        submissionId: submissionId,
        initialAttachments: attachments,
      );
      final schemaVersionRaw =
          (submission['schemaVersion'] ?? submission['SchemaVersion']);
      final schemaVersion = schemaVersionRaw is int
          ? schemaVersionRaw
          : int.tryParse(schemaVersionRaw?.toString() ?? '');
      final submittedAtRaw =
          (submission['submittedAtUtc'] ?? submission['SubmittedAtUtc'] ?? '')
              .toString()
              .trim();
      final submittedAtUtc = DateTime.tryParse(submittedAtRaw);

      if (!mounted) return;

      setState(() {
        _session = session;
        _submission = submission;
        _loading = false;
      });

      if (_isAutoResubmit) {
        await _runAutoResubmit(
          payload: payload,
          formData: formData,
          schemaVersion: schemaVersion,
          submittedAtUtc: submittedAtUtc,
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna'),
          builder: (_) => HnaWebEditorFormScreen(
            ticket: widget.ticket,
            submissionId: submissionId,
            submittedAtUtc: submittedAtUtc,
            schemaVersion: schemaVersion,
            originalPayload: payload,
            initialFormData: formData,
            clients: clients,
            service: _service,
            returnUrl: _returnUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final diagError = _withDiag(e.toString());
      setState(() {
        _error = diagError;
        _loading = false;
      });

      _logDiag('load-error', {
        'ticket': _ticketPreview(widget.ticket),
        'error': e.toString(),
      });

      if (kIsWeb && _isAutoResubmit) {
        WebEditorReturn.notifyParentError(
          ticket: widget.ticket,
          message: diagError,
        );
      }
    }
  }

  Future<void> _completeConditionReportWebEditor(
    FormEditorCompletion completion,
  ) async {
    final payload = CrSubmissionPayloadBuilder.buildFromFormSnapshot(
      formSnapshot: completion.formData,
      originalPayload: _crOriginalPayload,
      formId: completion.localFormId,
      formUuid: completion.formUuid,
      submittedAt: DateTime.now().toUtc(),
    );

    await _service.updateSubmission(
      ticket: widget.ticket,
      payloadJson: jsonEncode(payload),
      generatePdf: false,
    );

    if (kIsWeb) {
      WebEditorReturn.notifyParentComplete(
        ticket: widget.ticket,
        returnUrl: _returnUrl,
      );

      if (_returnUrl != null && _returnUrl!.isNotEmpty) {
        WebEditorReturn.returnToCaller(
          _returnUrl!,
          ticket: widget.ticket,
          preferClose: false,
        );
      }
    }
  }

  String _resolveSessionFormType(Map<String, dynamic> session) {
    final raw =
        (session['formType'] ??
                session['FormType'] ??
                session['ticketFormType'] ??
                session['TicketFormType'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    return raw;
  }

  Future<void> _runAutoResubmit({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> formData,
    required int? schemaVersion,
    required DateTime? submittedAtUtc,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final updatedPayload = _buildUpdatedPayload(
        originalPayload: payload,
        formData: formData,
        schemaVersion: schemaVersion,
        submittedAtUtc: submittedAtUtc,
      );

      final payloadJson = jsonEncode(_makeJsonEncodable(updatedPayload));
      await _service.updateSubmission(
        ticket: widget.ticket,
        payloadJson: payloadJson,
        generatePdf: true,
      );

      if (kIsWeb) {
        WebEditorReturn.notifyParentComplete(
          ticket: widget.ticket,
          returnUrl: _returnUrl,
        );
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final diagError = _withDiag(e.toString());
      if (kIsWeb) {
        WebEditorReturn.notifyParentError(
          ticket: widget.ticket,
          message: diagError,
        );
      }

      if (!mounted) return;
      setState(() {
        _error = diagError;
        _loading = false;
      });

      _logDiag('auto-resubmit-error', {
        'ticket': _ticketPreview(widget.ticket),
        'error': e.toString(),
      });
    }
  }

  String _withDiag(String message) {
    return '[diag build=$_buildId source=$_definesSource ticket=${_ticketPreview(widget.ticket)}] $message';
  }

  String _ticketPreview(String ticket) {
    final t = ticket.trim();
    if (t.length <= 8) return t;
    return '${t.substring(0, 8)}...';
  }

  void _logDiag(String event, Map<String, Object?> fields) {
    if (!kDebugMode && !kIsWeb) {
      return;
    }

    final details = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      '[APM_WEB_EDITOR] $event build=$_buildId source=$_definesSource $details',
    );
  }

  dynamic _makeJsonEncodable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is String || value is bool) return value;
    if (value is List) return value.map(_makeJsonEncodable).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _makeJsonEncodable(v)));
    }
    return value.toString();
  }

  Map<String, dynamic> _buildUpdatedPayload({
    required Map<String, dynamic> originalPayload,
    required Map<String, dynamic> formData,
    required int? schemaVersion,
    required DateTime? submittedAtUtc,
  }) {
    final out = Map<String, dynamic>.from(originalPayload);

    final rawHna = out['hna'];
    final hna = rawHna is Map
        ? Map<String, dynamic>.from(rawHna)
        : <String, dynamic>{};

    final formDataOut = Map<String, dynamic>.from(formData);

    _ensureV4Envelope(
      out: out,
      hna: hna,
      formData: formDataOut,
      submittedAtUtc: submittedAtUtc,
    );

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
          assetsJson: assets is Map ? Map<String, dynamic>.from(assets) : null,
          observationsJson: observations is List
              ? List<dynamic>.from(observations)
              : null,
          unsafeJson: unsafe is Map ? Map<String, dynamic>.from(unsafe) : null,
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
    if (reportNumber != null &&
        reportNumber.trim().isNotEmpty &&
        assets is Map) {
      final assetsMap = Map<String, dynamic>.from(assets);
      final unsafeObservationsJson = _tryReadMapList(
        unsafe is Map ? unsafe['unsafeObservations'] : null,
      );
      final unsafeReportsJson = _tryReadMapList(
        unsafe is Map ? unsafe['unsafeReports'] : null,
      );
      final attachmentsJson = _tryReadMapList(attachments);
      final observationsJson = _tryReadMapList(observations);

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

    hna['formData'] = formDataOut;
    out['hna'] = hna;

    return out;
  }

  void _ensureV4Envelope({
    required Map<String, dynamic> out,
    required Map<String, dynamic> hna,
    required Map<String, dynamic> formData,
    required DateTime? submittedAtUtc,
  }) {
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

    final submittedAt = (submittedAtUtc ?? DateTime.now()).toUtc();
    final existingFriendlyRef = (summary['friendlyRef'] ?? '')
        .toString()
        .trim();
    final friendlyRef = existingFriendlyRef.isNotEmpty
        ? existingFriendlyRef
        : HnaSubmissionPayloadBuilder.buildFriendlyRef(
            submittedAt: submittedAt,
            formUuid: formUuid,
          );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_isAutoResubmit)
                    _MetaRow(session: _session, submission: _submission)
                  else
                    const Text('Recomputing metrics...'),
                ],
              ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.session, required this.submission});

  final Map<String, dynamic>? session;
  final Map<String, dynamic>? submission;

  String _readString(Map<String, dynamic>? map, String key) {
    if (map == null) return '';
    final v = map[key] ?? map[_pascal(key)];
    return v?.toString() ?? '';
  }

  String _pascal(String key) {
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final submissionId = _readString(submission, 'submissionId');
    final schemaVersion = _readString(submission, 'schemaVersion');
    final submittedAtUtc = _readString(submission, 'submittedAtUtc');
    final expiresAtUtc = _readString(session, 'expiresAtUtc');

    final parts = <String>[
      if (submissionId.isNotEmpty) 'Submission: $submissionId',
      if (schemaVersion.isNotEmpty) 'Schema: $schemaVersion',
      if (submittedAtUtc.isNotEmpty) 'Submitted: $submittedAtUtc',
      if (expiresAtUtc.isNotEmpty) 'Ticket expires: $expiresAtUtc',
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' • '),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
