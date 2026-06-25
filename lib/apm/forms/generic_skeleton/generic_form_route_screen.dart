import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'form_definition_catalog_service.dart';
import 'generic_form_submission_service.dart';
import 'server_forms_screen.dart';

/// Opens a generic (data-defined) form by id — the target of a backend-driven
/// menu tap (route scheme `form:<id>`, produced by the navigation mapper).
///
/// Fetches the [gtmobile.FormPackage] via [FormDefinitionCatalogService] (the
/// same path the forms list uses) and renders it through [ServerFormRenderScreen]
/// with the standard [GenericFormSubmissionService], so save/submit behave
/// exactly as when opened from the list.
class GenericFormRouteScreen extends StatefulWidget {
  const GenericFormRouteScreen({super.key, required this.formId});

  final String formId;

  @override
  State<GenericFormRouteScreen> createState() => _GenericFormRouteScreenState();
}

class _GenericFormRouteScreenState extends State<GenericFormRouteScreen> {
  final FormDefinitionCatalogService _catalog = FormDefinitionCatalogService();
  late final Future<gtmobile.FormPackage> _future =
      _catalog.fetchDefinition(id: widget.formId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<gtmobile.FormPackage>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          // Engine guard: this form needs controls a newer app build provides.
          final err = snapshot.error;
          if (err is gtmobile.FormEngineTooOldException) {
            return Scaffold(
              appBar: AppBar(title: const Text('Update required')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'This form needs a newer version of the app.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'It uses features this app build does not support yet: '
                        '${err.unsupportedTypes.join(", ")}.\n\n'
                        'Please update Audit Pro Mobile to fill in this form.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Form')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this form.\n${err ?? ''}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return ServerFormRenderScreen(
          package: snapshot.data!,
          submissionService: GenericFormSubmissionService(),
        );
      },
    );
  }
}
