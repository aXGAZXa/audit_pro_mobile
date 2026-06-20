import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;
import 'package:uuid/uuid.dart';

import '../condition_report/condition_report_definition.dart';
import '../condition_report/condition_report_screen.dart';
import '../condition_report/services/cr_submission_payload_builder.dart';
import '../generic_skeleton/form_definition_catalog_service.dart';
import '../shared/data/web_form_repository.dart';
import '../shared/editor/form_editor_contract.dart';
import 'heat_network_assessment_definition.dart';
import 'heat_network_assessment_screen.dart';
import '../../services/portal_api_client.dart';
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

  /// GENERIC web editor attachment manifest: attachmentId -> record
  /// `{id, key, contentType, fileName, sizeBytes, width?, height?}`.
  ///
  /// Seeded from the loaded envelope's `attachments[]` and mutated by the
  /// editable image gallery's add/delete (via the [gtmobile.GTFileManagerConfig]
  /// upload/delete hooks installed in [_routeGeneric]). On save, the envelope's
  /// `attachments[]` is rebuilt from this manifest restricted to the image ids
  /// still referenced across the form's image-question answers, so deleted
  /// images disappear and added ones appear (no stale carry-through).
  final Map<String, Map<String, dynamic>> _genericAttachmentManifest = {};

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

        final crFormSection = payload['form'];
        final crLocalFormId = crFormSection is Map
            ? int.tryParse((crFormSection['formId'] ?? '').toString())
            : null;
        final crFormUuid = crFormSection is Map
            ? (crFormSection['uuid'] ?? '').toString()
            : null;

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/cr-web-editor'),
            builder: (_) => ConditionReportScreen(
              mode: FormEditorRuntimeMode.webEditor,
              formId: crLocalFormId,
              repo: WebFormRepository(
                service: _service,
                ticket: widget.ticket,
                formType: kConditionReportFormType,
                formId: crLocalFormId ?? 0,
                initialData: formData,
                generatePdfOnSubmit: false,
                buildPayloadJson: (data) async => jsonEncode(
                  CrSubmissionPayloadBuilder.buildFromFormSnapshot(
                    formSnapshot: data,
                    originalPayload: _crOriginalPayload,
                    formId: crLocalFormId,
                    formUuid: crFormUuid,
                    submittedAt: DateTime.now().toUtc(),
                  ),
                ),
              ),
              onCompleted: () async {
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
              },
            ),
          ),
        );
        return;
      }

      if (ticketFormType.isNotEmpty &&
          ticketFormType != kHeatNetworkAssessmentFormType) {
        // Generic (builder-authored) form types render + edit + save through the
        // generic declarative runtime. This is additive: CR/HNA keep their
        // bespoke branches above; everything else now flows here instead of
        // throwing. The throw remains only as a fallback if the definition
        // fetch genuinely fails (see _routeGeneric).
        await _routeGeneric(
          ticketFormType: ticketFormType,
          submission: submission,
        );
        return;
      }

      _logDiag('route-hna', {'ticket': _ticketPreview(widget.ticket)});

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

      // Reconstruct the in-memory HNA document (the form_data blob shape) that
      // the unified screen + WebFormRepository operate on, mirroring mobile.
      final hnaFormSection = payload['form'];
      final hnaFormId = hnaFormSection is Map
          ? int.tryParse((hnaFormSection['id'] ?? '').toString())
          : null;
      final hnaFormUuid = hnaFormSection is Map ? hnaFormSection['uuid'] : null;
      final hnaFormStatus = hnaFormSection is Map
          ? hnaFormSection['status']
          : null;
      final hnaFormCreatedAt = hnaFormSection is Map
          ? hnaFormSection['createdAt']
          : null;
      final hnaFormUpdatedAt = hnaFormSection is Map
          ? hnaFormSection['updatedAt']
          : null;
      final hnaSummary = hna['summary'];
      // Preserve the original submit time so the device-minted friendlyRef
      // (report number) stays stable across edits.
      final hnaSubmittedAt =
          submittedAtUtc ??
          DateTime.tryParse(
            (hnaSummary is Map ? (hnaSummary['submittedAt'] ?? '') : '')
                .toString(),
          );

      final hnaDoc = <String, dynamic>{
        'formData': formData,
        'assets': hna['assets'] is Map
            ? Map<String, dynamic>.from(hna['assets'] as Map)
            : <String, dynamic>{},
        'observations': hna['observations'] is List
            ? List<dynamic>.from(hna['observations'] as List)
            : <dynamic>[],
        'unsafe': hna['unsafe'] is Map
            ? Map<String, dynamic>.from(hna['unsafe'] as Map)
            : <String, dynamic>{},
      };

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna'),
          builder: (_) => HeatNetworkAssessmentScreen(
            formId: hnaFormId,
            repo: WebFormRepository(
              service: _service,
              ticket: widget.ticket,
              formType: kHeatNetworkAssessmentFormType,
              formId: hnaFormId ?? 0,
              initialData: hnaDoc,
              generatePdfOnSubmit: true,
              buildPayloadJson: (data) async {
                // Build the attachment manifest from the editor context so the
                // server's existing att-ids for already-uploaded blobs are
                // preserved (else the PDF can't resolve the images on a revision).
                final fd = data['formData'] is Map
                    ? Map<String, dynamic>.from(data['formData'] as Map)
                    : <String, dynamic>{};
                final assets = data['assets'] is Map
                    ? Map<String, dynamic>.from(data['assets'] as Map)
                    : <String, dynamic>{};
                final obs = data['observations'] is List
                    ? (data['observations'] as List)
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList()
                    : <Map<String, dynamic>>[];
                final unsafe = data['unsafe'] is Map
                    ? Map<String, dynamic>.from(data['unsafe'] as Map)
                    : <String, dynamic>{};
                final manifest = FormWebEditorAttachmentContext.instance
                    .buildManifest(
                      formId: hnaFormId ?? 0,
                      formData: fd,
                      assetsJson: assets,
                      observationsJson: obs,
                      unsafeJson: unsafe,
                    );
                return jsonEncode(
                  await HnaSubmissionPayloadBuilder.buildFromFormSnapshot(
                    formSnapshot: data,
                    formId: hnaFormId ?? 0,
                    formUuid: hnaFormUuid,
                    formType: kHeatNetworkAssessmentFormType,
                    status: hnaFormStatus,
                    createdAt: hnaFormCreatedAt,
                    updatedAt: hnaFormUpdatedAt,
                    submittedAt: hnaSubmittedAt,
                    recomputeDerived: true,
                    attachmentsOverride: manifest,
                  ),
                );
              },
            ),
            onCompleted: () async {
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
            },
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


  /// Renders + edits + saves a generic (builder-authored) form submission on the
  /// generic declarative runtime.
  ///
  /// 1. Fetches the published form definition (by formDefinitionId if the stored
  ///    envelope carries one, else by formType) -> [gtmobile.FormPackage].
  /// 2. Seeds the runtime from the stored generic envelope's `response` object
  ///    (a `FormState.toJson()` map) via [gtmobile.FormState.fromJson]. Guards an
  ///    empty/absent response (new-ish row) by rendering unseeded.
  /// 3. Renders [gtmobile.GTDeclarativeFormView] with `initialState`.
  /// 4. On complete, rebuilds the envelope with `response` replaced by the new
  ///    `FormState.toJson()` (preserving identity fields) and PUTs it via the
  ///    same web-editor update path CR/HNA use.
  Future<void> _routeGeneric({
    required String ticketFormType,
    required Map<String, dynamic> submission,
  }) async {
    _logDiag('route-generic', {
      'ticket': _ticketPreview(widget.ticket),
      'formType': ticketFormType,
    });

    // The GET-submission PayloadJson IS the stored generic envelope.
    final payloadJson =
        (submission['payloadJson'] ?? submission['PayloadJson'] ?? '')
            .toString()
            .trim();

    Map<String, dynamic> envelope = <String, dynamic>{};
    if (payloadJson.isNotEmpty) {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) {
        envelope = Map<String, dynamic>.from(decoded);
      }
    }

    // Prefer fetching by the pinned definition id if the envelope carries one;
    // else fall back to latest-by-formType.
    final envelopeDefinitionId =
        (envelope['formDefinitionId'] ?? envelope['FormDefinitionId'] ?? '')
            .toString()
            .trim();

    // The web editor authenticates by TICKET (no JWT), so it CANNOT use the app's
    // JWT-scoped definition catalog (that throws "You are not signed in"). The server
    // bundles the published definition into this ticket-authed snapshot — prefer it.
    // Only fall back to the catalog for the in-app context (where a token exists).
    final snapshotDefinitionJson =
        (submission['definitionJson'] ?? submission['DefinitionJson'] ?? '')
            .toString()
            .trim();

    final gtmobile.FormPackage package;
    if (snapshotDefinitionJson.isNotEmpty) {
      final decodedDef = jsonDecode(snapshotDefinitionJson);
      package = gtmobile.FormPackage.fromJson(
        Map<String, dynamic>.from(decodedDef as Map),
      );
    } else {
      final catalog = FormDefinitionCatalogService();
      package = envelopeDefinitionId.isNotEmpty
          ? await catalog.fetchDefinition(id: envelopeDefinitionId)
          : await catalog.fetchDefinition(formType: ticketFormType);
    }

    // Install the remote image resolver so the generic image question renders
    // EXISTING images from R2 (read-only) instead of querying the local
    // GTDatabaseService (unavailable on web). The image answer is a list of
    // image ids that are IDENTICAL to the R2 attachment ids, so we fetch each by
    // id through the SAME ticket-authed endpoint used elsewhere
    // (GET /api/editor/attachments/{id}/content). Add/delete is out of scope.
    final ticket = widget.ticket;
    final service = _service;
    gtmobile.GTFileManagerConfig.remoteImageResolver = (String imageId) async {
      final id = imageId.trim();
      if (id.isEmpty) return null;
      try {
        final bytes = await service.getAttachmentBytes(
          ticket: ticket,
          attachmentId: id,
        );
        return Uint8List.fromList(bytes);
      } catch (e) {
        _logDiag('generic-remote-image-failed', {
          'ticket': _ticketPreview(ticket),
          'imageId': id,
          'error': e.toString(),
        });
        return null;
      }
    };

    // Seed the editor-side attachment manifest from the stored envelope so adds
    // and deletes mutate a single source of truth that the save reconciliation
    // reads. Each entry is keyed by its attachment id (== image id == R2
    // attachment id).
    _genericAttachmentManifest.clear();
    final seedAttachments = envelope['attachments'] ?? envelope['Attachments'];
    if (seedAttachments is List) {
      for (final raw in seedAttachments) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = (map['id'] ?? map['Id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        _genericAttachmentManifest[id] = map;
      }
    }

    // ADD hook: mint a new attachment id, presign + PUT the bytes (ticket-authed),
    // record the returned key in the manifest, and return the id so the image
    // question appends it to its answer.
    gtmobile.GTFileManagerConfig.remoteImageUploader =
        (Uint8List bytes, String fileName, String contentType) async {
          final attachmentId = const Uuid().v4();
          final record = await service.uploadGenericAttachment(
            ticket: ticket,
            attachmentId: attachmentId,
            bytes: bytes,
            fileName: fileName,
            contentType: contentType,
          );
          _genericAttachmentManifest[attachmentId] =
              Map<String, dynamic>.from(record);
          _logDiag('generic-remote-image-added', {
            'ticket': _ticketPreview(ticket),
            'imageId': attachmentId,
          });
          return attachmentId;
        };

    // DELETE hook: best-effort R2 delete (ticket-authed) + manifest removal. The
    // envelope reference is dropped by the save reconciliation. A storage delete
    // failure must NOT block the UI removal, so swallow it (the object becomes
    // orphaned at worst; the reference is still removed on save).
    gtmobile.GTFileManagerConfig.remoteImageDeleter = (String imageId) async {
      final id = imageId.trim();
      if (id.isEmpty) return;
      try {
        await service.deleteGenericAttachment(ticket: ticket, attachmentId: id);
      } catch (e) {
        _logDiag('generic-remote-image-delete-failed', {
          'ticket': _ticketPreview(ticket),
          'imageId': id,
          'error': e.toString(),
        });
      }
      _genericAttachmentManifest.remove(id);
    };

    // Seed from the submitted answers. The envelope's `response` object is the
    // FormState.toJson() map. Guard absence / empty (new-ish row -> unseeded).
    final responseRaw = envelope['response'] ?? envelope['Response'];
    gtmobile.FormState? seededState;
    if (responseRaw is Map && responseRaw.isNotEmpty) {
      try {
        seededState = gtmobile.FormState.fromJson(
          responseRaw.map((k, v) => MapEntry(k.toString(), v)),
        );
      } catch (e) {
        // A malformed/incompatible stored response should not block editing;
        // fall back to an unseeded render so the user can re-author.
        _logDiag('generic-seed-failed', {
          'ticket': _ticketPreview(widget.ticket),
          'error': e.toString(),
        });
        seededState = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _session = _session ?? const <String, dynamic>{};
      _submission = submission;
      _loading = false;
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/generic-web-editor'),
        builder: (_) => _GenericWebEditorScaffold(
          package: package,
          initialState: seededState,
          onFormComplete: (gtmobile.FormState state) async {
            await _saveGenericSubmission(
              originalEnvelope: envelope,
              package: package,
              state: state,
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
          },
        ),
      ),
    );
  }

  /// Builds a fresh generic envelope = the original envelope with its `response`
  /// replaced by the edited `state.toJson()`, preserving identity fields, then
  /// PUTs it through the existing web-editor update path (same as CR/HNA).
  Future<void> _saveGenericSubmission({
    required Map<String, dynamic> originalEnvelope,
    required gtmobile.FormPackage package,
    required gtmobile.FormState state,
  }) async {
    final out = Map<String, dynamic>.from(originalEnvelope);
    final definition = package.formDefinition;

    // Preserve identity from the original envelope where present; backfill from
    // the definition / state so a sparse (new-ish) envelope still round-trips.
    out['formType'] =
        (originalEnvelope['formType'] ?? originalEnvelope['FormType']) ??
            definition.formType;
    out['formDefinitionId'] =
        (originalEnvelope['formDefinitionId'] ??
            originalEnvelope['FormDefinitionId']) ??
        (state.formDefinitionId.isNotEmpty
            ? state.formDefinitionId
            : definition.id);
    out['formDefinitionVersion'] =
        (originalEnvelope['formDefinitionVersion'] ??
            originalEnvelope['FormDefinitionVersion']) ??
        (state.schemaVersion ?? definition.version);
    // Keep clientResponseId so identity is stable across edits.
    final clientResponseId = originalEnvelope['clientResponseId'] ??
        originalEnvelope['ClientResponseId'];
    if (clientResponseId != null) {
      out['clientResponseId'] = clientResponseId;
    }
    // Preserve the original submit time so the report identity stays stable.
    final submittedAt = originalEnvelope['submittedAtUtc'] ??
        originalEnvelope['SubmittedAtUtc'];
    if (submittedAt != null) {
      out['submittedAtUtc'] = submittedAt;
    }

    // The edited answers.
    out['response'] = state.toJson();

    // RECONCILE attachments[]: write exactly the images still referenced across
    // the form's image-question answers, resolving their records from the
    // editor-side manifest (seeded from the original envelope, mutated by
    // add/delete). Deleted images drop out; added images appear. Do NOT carry
    // the original list through untouched.
    out['attachments'] = _reconcileGenericAttachments(
      package: package,
      state: state,
    );

    await _service.updateSubmission(
      ticket: widget.ticket,
      payloadJson: jsonEncode(out),
      generatePdf: false,
    );
  }

  /// Build the envelope `attachments[]` from the manifest, restricted to the
  /// image ids still referenced by the form's image-question answers in [state].
  ///
  /// Walks every [gtmobile.ImageQuestion] in the definition, reads its answer
  /// (a list of image ids — or a single id) from the final [state], and emits
  /// one manifest record per referenced id. Ids without a manifest record (e.g.
  /// an image that existed in the original envelope but never had an
  /// attachments[] entry) are emitted as a minimal `{id}` record so the
  /// reference is preserved and the server can still resolve it.
  List<Map<String, dynamic>> _reconcileGenericAttachments({
    required gtmobile.FormPackage package,
    required gtmobile.FormState state,
  }) {
    final referenced = <String>{};

    final imageQuestions = <gtmobile.ImageQuestion>[];
    for (final section in package.formDefinition.sections) {
      imageQuestions.addAll(
        section.getAllElementsOfType<gtmobile.ImageQuestion>(),
      );
    }

    final answersById = state.answersByQuestionId;
    for (final q in imageQuestions) {
      dynamic answer = state.answers[q.id];
      answer ??= state.answers[q.displayReference];
      if (answer == null && answersById != null) {
        answer = answersById[q.id];
      }

      if (answer is List) {
        for (final v in answer) {
          final id = v?.toString().trim() ?? '';
          if (id.isNotEmpty) referenced.add(id);
        }
      } else if (answer is String && answer.trim().isNotEmpty) {
        referenced.add(answer.trim());
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final id in referenced) {
      final record = _genericAttachmentManifest[id];
      if (record != null) {
        out.add(Map<String, dynamic>.from(record));
      } else {
        // Referenced but unknown to the manifest — preserve the reference.
        out.add(<String, dynamic>{'id': id});
      }
    }

    _logDiag('generic-attachments-reconciled', {
      'ticket': _ticketPreview(widget.ticket),
      'referenced': referenced.length,
      'manifest': _genericAttachmentManifest.length,
    });

    return out;
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

/// Hosts the generic declarative runtime for a web-editor session, seeded with
/// the existing submission's answers and saving back via [onFormComplete].
///
/// Mirrors `ServerFormRenderScreen` (the CREATE flow) except it threads
/// `initialState` for seeding and delegates persistence to the supplied
/// completion callback (which rebuilds the envelope + PUTs it).
class _GenericWebEditorScaffold extends StatefulWidget {
  const _GenericWebEditorScaffold({
    required this.package,
    required this.initialState,
    required this.onFormComplete,
  });

  final gtmobile.FormPackage package;
  final gtmobile.FormState? initialState;
  final Future<void> Function(gtmobile.FormState state) onFormComplete;

  @override
  State<_GenericWebEditorScaffold> createState() =>
      _GenericWebEditorScaffoldState();
}

class _GenericWebEditorScaffoldState extends State<_GenericWebEditorScaffold> {
  bool _saving = false;

  Future<void> _handleComplete(gtmobile.FormState state) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onFormComplete(state);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        gtmobile.GTDeclarativeFormView(
          package: widget.package,
          initialState: widget.initialState,
          onFormComplete: _handleComplete,
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
