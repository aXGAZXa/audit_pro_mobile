import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'form_definition_catalog_service.dart';
import 'generic_form_attachment_upload_service.dart';
import 'generic_form_submission_service.dart';

/// DEV/BETA screen for the forms-unification "delivery" slice (S3).
///
/// Lists server-published form definitions, then fetches and renders a selected
/// one through the SAME generic declarative runtime the bundled skeleton uses
/// ([gtmobile.GTDeclarativeFormView]) and submits the generic envelope via
/// [GenericFormSubmissionService]. This closes the "new form, no app update"
/// delivery loop.
///
/// NON-DISRUPTIVE: additive, new-file only. Reachable from a debug-only entry in
/// Settings. Does not touch live CR/HNA screens, submit flows, or local DB.
class ServerFormsScreen extends StatefulWidget {
  const ServerFormsScreen({
    super.key,
    this.catalogService,
    this.submissionService,
  });

  /// Override for tests; defaults to a real [FormDefinitionCatalogService].
  final FormDefinitionCatalogService? catalogService;

  /// Override for tests; defaults to a real [GenericFormSubmissionService].
  final GenericFormSubmissionService? submissionService;

  @override
  State<ServerFormsScreen> createState() => _ServerFormsScreenState();
}

class _ServerFormsScreenState extends State<ServerFormsScreen> {
  late final FormDefinitionCatalogService _catalog =
      widget.catalogService ?? FormDefinitionCatalogService();

  late Future<List<FormDefinitionSummary>> _listFuture;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _listFuture = _catalog.listDefinitions();
  }

  void _reload() {
    setState(() {
      _listFuture = _catalog.listDefinitions();
    });
  }

  Future<void> _openDefinition(FormDefinitionSummary summary) async {
    if (_openingId != null) return;
    setState(() => _openingId = summary.id);

    final navigator = Navigator.of(context);
    try {
      // Prefer the stable id; fall back to latest-by-formType if absent.
      final package = summary.id.isNotEmpty
          ? await _catalog.fetchDefinition(id: summary.id)
          : await _catalog.fetchDefinition(formType: summary.formType);

      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ServerFormRenderScreen(
            package: package,
            submissionService:
                widget.submissionService ?? GenericFormSubmissionService(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Could not load that form definition. See logs for details.',
        category: 'GenericForms/Server',
        logMessage: 'Server form fetch threw for id={Id}: {Error}',
        logArgs: [summary.id, e.toString()],
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Forms (beta)'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<FormDefinitionSummary>>(
        future: _listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            ApmLogger.warning(
              'Failed to list server form definitions: {Error}',
              args: [snapshot.error.toString()],
              category: 'GenericForms/Server',
            );
            return _ErrorState(
              message:
                  'Could not load published form definitions.\n${snapshot.error}',
              onRetry: _reload,
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _ErrorState(
              icon: Icons.inbox_outlined,
              message:
                  'No published form definitions found.\n\nPublish a definition '
                  'to the server store, then reload.',
              onRetry: _reload,
              retryLabel: 'Reload',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final opening = _openingId == item.id;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(item.displayName),
                  subtitle: Text(
                    [
                      if (item.formType.isNotEmpty) 'type: ${item.formType}',
                      if (item.version.isNotEmpty) 'v${item.version}',
                      if (item.status.isNotEmpty) item.status,
                    ].join('  •  '),
                  ),
                  trailing: opening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _openingId == null ? () => _openDefinition(item) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Renders a fetched [gtmobile.FormPackage] and submits the generic envelope on
/// completion. This mirrors `SkeletonDemoScreen` exactly, except the package is
/// supplied (already fetched) and the submit `formType` comes from the fetched
/// definition rather than a hardcoded slug.
///
/// Public so the live forms home (declared-forms section) can reuse the exact
/// same render+submit path as the debug Server Forms beta screen.
class ServerFormRenderScreen extends StatefulWidget {
  const ServerFormRenderScreen({
    super.key,
    required this.package,
    required this.submissionService,
  });

  final gtmobile.FormPackage package;
  final GenericFormSubmissionService submissionService;

  @override
  State<ServerFormRenderScreen> createState() =>
      _ServerFormRenderScreenState();
}

class _ServerFormRenderScreenState extends State<ServerFormRenderScreen> {
  bool _submitting = false;

  Future<void> _handleComplete(gtmobile.FormState state) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final navigator = Navigator.of(context);
    // formType for the submit envelope = the published definition's formType.
    final formType = widget.package.formDefinition.formType;
    try {
      final responseId = await widget.submissionService.submit(
        formType: formType,
        formDefinitionId: state.formDefinitionId,
        formDefinitionVersion: state.schemaVersion ?? 1,
        responseJson: state.toJson(),
        package: widget.package,
      );

      if (!mounted) return;
      ApmFeedback.success(
        context,
        'Form submitted (responseId: $responseId).',
        category: 'GenericForms/Server',
      );
      navigator.maybePop();
    } on GenericAttachmentUploadException catch (e) {
      // Photos failed to upload — keep the draft/local images, abort submit.
      if (!mounted) return;
      ApmFeedback.error(
        context,
        e.message,
        category: 'GenericForms/Server',
        logMessage: 'Server form attachment upload failed formType={Type}: {Error}',
        logArgs: [formType, e.toString()],
      );
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Submit failed. See logs for details.',
        category: 'GenericForms/Server',
        logMessage: 'Server form submit threw formType={Type}: {Error}',
        logArgs: [formType, e.toString()],
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        gtmobile.GTDeclarativeFormView(
          package: widget.package,
          onFormComplete: _handleComplete,
        ),
        if (_submitting)
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
