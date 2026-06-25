import 'package:flutter/material.dart';

import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/screens/widgets/form_card.dart';
import 'form_definition_catalog_service.dart';
import 'generic_form_submission_service.dart';
import 'server_forms_screen.dart' show ServerFormRenderScreen;

/// DEVELOPER page — lists THIS app's DEV (unpublished working-copy) form definitions and opens them
/// through the same generic runtime as Home. App-scoped: it calls the app-scoped delivery endpoint with
/// `dev=true`, so the server returns only this app's dev forms (gated on the `is_developer` claim) — it
/// does NOT list other apps' forms. Reached only from the drawer's developer-gated entry.
class DeveloperFormsScreen extends StatefulWidget {
  const DeveloperFormsScreen({
    super.key,
    this.catalogService,
    this.submissionService,
  });

  final FormDefinitionCatalogService? catalogService;
  final GenericFormSubmissionService? submissionService;

  @override
  State<DeveloperFormsScreen> createState() => _DeveloperFormsScreenState();
}

class _DeveloperFormsScreenState extends State<DeveloperFormsScreen> {
  late final FormDefinitionCatalogService _catalog =
      widget.catalogService ?? FormDefinitionCatalogService();

  late Future<List<FormDefinitionSummary>> _listFuture;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _listFuture = _load();
  }

  // App-scoped DEV forms (the keying fix: this is `/api/forms/app/definitions?dev=true`, NOT the global
  // list the old beta screen used — so only THIS app's dev forms come back).
  Future<List<FormDefinitionSummary>> _load() => _catalog.listAppDefinitions(dev: true);

  void _reload() => setState(() => _listFuture = _load());

  Future<void> _openDefinition(FormDefinitionSummary summary) async {
    if (_openingId != null) return;
    setState(() => _openingId = summary.id);

    final navigator = Navigator.of(context);
    try {
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
        category: 'GenericForms/Developer',
        logMessage: 'Developer form fetch threw for id={Id}: {Error}',
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
        title: const Text('Developer — Dev Forms'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
              'Failed to list developer (dev) form definitions: {Error}',
              args: [snapshot.error.toString()],
              category: 'GenericForms/Developer',
            );
            return _CenterMessage(
              icon: Icons.error_outline,
              message: 'Could not load dev form definitions.\n${snapshot.error}',
              onRetry: _reload,
            );
          }

          final items = snapshot.data ?? const <FormDefinitionSummary>[];
          if (items.isEmpty) {
            return _CenterMessage(
              icon: Icons.inbox_outlined,
              message:
                  'No dev (unpublished) forms for this app.\n\nForms appear here while they are in the '
                  'dev working copy; once published they move to Home.',
              onRetry: _reload,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final opening = _openingId == item.id;
              // Same card as Home (FormCard), so Home and Developer look identical. The whole page is
              // dev, so the card shows the DEV per-form version on line 2.
              return FormCard(
                title: item.displayName,
                description: 'Dev v${item.schemaVersion}.${item.revision}',
                icon: Icons.description_outlined,
                color: Colors.teal.shade400,
                trailing: opening
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _openingId == null ? () => _openDefinition(item) : () {},
              );
            },
          );
        },
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

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
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
