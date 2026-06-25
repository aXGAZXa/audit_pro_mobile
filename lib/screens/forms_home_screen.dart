import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import '../app/app_scaffold.dart';
import '../app/app_shell_config.dart';
import 'widgets/form_card.dart';
import '../apm/database/database_helper.dart';
import '../apm/forms/condition_report/condition_report_definition.dart';
import '../apm/forms/condition_report/condition_report_screen.dart';
import '../apm/forms/condition_report/cr_repository_factory.dart';
import '../apm/forms/generic_skeleton/form_definition_catalog_service.dart';
import '../apm/forms/generic_skeleton/generic_form_submission_service.dart';
import '../apm/forms/generic_skeleton/server_forms_screen.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import '../auth/auth_session.dart';
import '../hna/heat_network_assessment/heat_network_assessment_screen.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';

class FormsHomeScreen extends StatefulWidget {
  const FormsHomeScreen({
    super.key,
    required this.session,
    this.catalogService,
  });

  final AuthSession session;

  /// Override for tests; defaults to a real [FormDefinitionCatalogService].
  final FormDefinitionCatalogService? catalogService;

  @override
  State<FormsHomeScreen> createState() => _FormsHomeScreenState();
}

class _FormsHomeScreenState extends State<FormsHomeScreen> {
  late final FormDefinitionCatalogService _catalog =
      widget.catalogService ?? FormDefinitionCatalogService();

  /// Server-declared (form-builder) forms scoped to THIS app by the JWT
  /// `app_id` claim. Loaded once on init; rendered ALONGSIDE the hardcoded
  /// CR/HNA cards. On empty or failure this resolves to an empty list so the
  /// hardcoded cards are never disturbed (see [_buildDeclaredFormsSection]).
  late Future<List<FormDefinitionSummary>> _declaredFormsFuture;

  String? _openingDeclaredId;

  @override
  void initState() {
    super.initState();
    _declaredFormsFuture = _loadDeclaredForms();
  }

  /// Fetches this app's declared forms, swallowing any failure (logged) so a
  /// fetch/parse problem can NEVER break the hardcoded cards. Returns [] on
  /// error → the section renders nothing.
  Future<List<FormDefinitionSummary>> _loadDeclaredForms() async {
    try {
      return await _catalog.listAppDefinitions();
    } catch (e, st) {
      ApmLogger.warning(
        'Declared forms list failed; hardcoded cards unaffected: {Error}',
        args: [e.toString()],
        category: 'GenericForms/Home',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Backend-driven home: when a home screen is delivered, render it via the
    // generic screen engine. Otherwise fall back to the built-in home below, so
    // the app is byte-identical to today when nothing is delivered.
    final homeScreen = AppShellConfig.of(context)?.homeScreen;
    if (homeScreen != null) {
      return AppScaffold(
        title: homeScreen.title.isNotEmpty
            ? homeScreen.title
            : 'Data Capture Forms',
        session: widget.session,
        body: gtmobile.GTScreenRenderer(
          screen: homeScreen,
          onAction: (ctx, action) => Navigator.pushNamed(ctx, action),
        ),
      );
    }

    return AppScaffold(
      title: 'Data Capture Forms',
      session: widget.session,
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshForms();
          await _declaredFormsFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legacy bespoke features (HNA, Condition Report) are HIDDEN for the app-driven POC — the
              // home now shows only the forms delivered for THIS app (via its app key). Code kept intact
              // for reference; flip _showLegacyFeatures to restore the tiles.
              if (_showLegacyFeatures) ...[
                _buildFormCard(
                  context,
                  title: 'Heat Network Assessment',
                  icon: Icons.network_check,
                  color: Colors.deepOrange.shade400,
                  onTap: () async {
                    await _openHnaFromHome(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildFormCard(
                  context,
                  title: 'Condition Report',
                  icon: Icons.assignment,
                  color: Colors.blue.shade400,
                  onTap: () async {
                    await _openCrFromHome(context);
                  },
                ),
              ],
              _buildDeclaredFormsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  /// POC: hide the hardcoded bespoke feature tiles (HNA, CR). The app-key handshake delivers this app's
  /// forms instead. Kept as a flag (not deleted) so the legacy tiles + their open handlers remain reference.
  final bool _showLegacyFeatures = false;

  /// Re-fetch the delivered forms for this app (the menu-derived "refresh form definitions" action).
  void _refreshForms() {
    setState(() {
      _declaredFormsFuture = _loadDeclaredForms();
    });
  }

  /// The ADDITIVE declared-forms section. Sits BELOW the hardcoded CR/HNA cards.
  /// - while loading: a small inline indicator.
  /// - empty result (or any error → []): renders NOTHING extra, so a fresh app
  ///   looks unchanged.
  /// - otherwise: a "Forms" header + one card per declared form.
  Widget _buildDeclaredFormsSection(BuildContext context) {
    return FutureBuilder<List<FormDefinitionSummary>>(
      future: _declaredFormsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final forms = snapshot.data ?? const <FormDefinitionSummary>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + the menu-derived "refresh form definitions" action (re-fetches this app's forms).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
              child: Row(
                children: [
                  Text('Forms', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh form definitions',
                    onPressed: loading ? null : _refreshForms,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (forms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text(
                  'No forms delivered for this app yet. Define and publish forms in the portal, then tap refresh.',
                ),
              )
            else
              for (final form in forms) ...[
              _buildFormCard(
                context,
                title: form.displayName,
                description:
                    'Live v${form.schemaVersion}.${form.revision}',
                icon: Icons.description_outlined,
                color: Colors.teal.shade400,
                trailing: _openingDeclaredId == form.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () async {
                  await _openDeclaredForm(form);
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  /// Fetches the declared form's [gtmobile.FormPackage] then pushes the shared
  /// [ServerFormRenderScreen] (the EXACT render+submit path used by the debug
  /// Server Forms beta) → renders via GTDeclarativeFormView → submits the
  /// generic envelope (formType from the package) to the generic endpoint.
  Future<void> _openDeclaredForm(FormDefinitionSummary form) async {
    if (_openingDeclaredId != null) return;
    setState(() => _openingDeclaredId = form.id);

    final navigator = Navigator.of(context);
    try {
      final package = form.id.isNotEmpty
          ? await _catalog.fetchDefinition(id: form.id)
          : await _catalog.fetchDefinition(formType: form.formType);

      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ServerFormRenderScreen(
            package: package,
            submissionService: GenericFormSubmissionService(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Could not open that form. See logs for details.',
        category: 'GenericForms/Home',
        logMessage: 'Declared form open failed id={Id}: {Error}',
        logArgs: [form.id, e.toString()],
      );
    } finally {
      if (mounted) setState(() => _openingDeclaredId = null);
    }
  }

  Future<void> _openCrFromHome(BuildContext context) async {
    final db = DatabaseHelper.instance;

    final drafts = await db.getFormsIndex(
      formType: kConditionReportFormType,
      statuses: const ['draft'],
    );

    if (!context.mounted) return;

    if (drafts.isNotEmpty) {
      final currentId = await db.getCurrentFormId(kConditionReportFormType);

      if (!context.mounted) return;

      final resumeId =
          (currentId != null &&
              drafts.any((d) => (d['id'] as int?) == currentId))
          ? currentId
          : (drafts.first['id'] as int);

      final choice = await showDialog<_HomeFormChoice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unfinished form found'),
            content: const Text(
              'You have an unfinished Condition Report. Do you want to start a new one or continue where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.resumeExisting),
                child: const Text('Continue'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.startNew),
                child: const Text('Start new'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (choice == null || choice == _HomeFormChoice.cancel) return;

      if (choice == _HomeFormChoice.resumeExisting) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/condition-report'),
            builder: (_) => ConditionReportScreen(
              formId: resumeId,
              repo: createCrMobileRepository(),
            ),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/condition-report'),
        builder: (_) => ConditionReportScreen(
        forceNew: true,
        repo: createCrMobileRepository(),
      ),
      ),
    );
  }

  Future<void> _openHnaFromHome(BuildContext context) async {
    final db = DatabaseHelper.instance;

    final drafts = await db.getFormsIndex(
      formType: kHeatNetworkAssessmentFormType,
      statuses: const ['draft'],
    );

    if (!context.mounted) return;

    if (drafts.isNotEmpty) {
      final currentId = await db.getCurrentFormId(
        kHeatNetworkAssessmentFormType,
      );

      if (!context.mounted) return;

      final resumeId =
          (currentId != null &&
              drafts.any((d) => (d['id'] as int?) == currentId))
          ? currentId
          : (drafts.first['id'] as int);

      final choice = await showDialog<_HomeFormChoice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unfinished form found'),
            content: const Text(
              'You have an unfinished Heat Network Assessment. Do you want to start a new one or continue where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.resumeExisting),
                child: const Text('Continue'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.startNew),
                child: const Text('Start new'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (choice == null || choice == _HomeFormChoice.cancel) return;

      if (choice == _HomeFormChoice.resumeExisting) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/hna'),
            builder: (_) => HeatNetworkAssessmentScreen(formId: resumeId),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/hna'),
        builder: (_) => const HeatNetworkAssessmentScreen(forceNew: true),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context, {
    required String title,
    String? description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) =>
      FormCard(
        title: title,
        description: description,
        icon: icon,
        color: color,
        onTap: onTap,
        trailing: trailing,
      );
}

enum _HomeFormChoice { cancel, startNew, resumeExisting }
