import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// gtapp_mobile re-exports all of gtapp_dart, so both the engine model types
// (FormPackage/FormState) and the renderer (GTDeclarativeFormView) come from
// this single dependency — audit_pro_mobile depends on gtapp_mobile only.
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'generic_form_attachment_upload_service.dart';
import 'generic_form_submission_service.dart';

/// DEV-ONLY walking-skeleton screen for the forms-unification project.
///
/// Loads the bundled `skeleton_demo` FormDefinition, renders it on the generic
/// declarative runtime ([gtmobile.GTDeclarativeFormView]), captures the
/// resulting [gtmobile.FormState], and POSTs it as a generic envelope via
/// [GenericFormSubmissionService].
///
/// NON-DISRUPTIVE: additive, new-file only. Reachable from a debug-only entry
/// in Settings. Does not touch live CR/HNA screens, submit flows, or local DB.
class SkeletonDemoScreen extends StatefulWidget {
  const SkeletonDemoScreen({super.key, this.submissionService});

  /// Asset path for the bundled skeleton FormPackage JSON.
  static const String assetPath = 'assets/forms/skeleton_demo.form.json';

  /// Override for tests; defaults to a real [GenericFormSubmissionService].
  final GenericFormSubmissionService? submissionService;

  @override
  State<SkeletonDemoScreen> createState() => _SkeletonDemoScreenState();
}

class _SkeletonDemoScreenState extends State<SkeletonDemoScreen> {
  late final GenericFormSubmissionService _submissionService =
      widget.submissionService ?? GenericFormSubmissionService();

  Future<gtmobile.FormPackage>? _packageFuture;
  gtmobile.FormPackage? _package;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _packageFuture = _loadPackage();
  }

  Future<gtmobile.FormPackage> _loadPackage() async {
    final raw = await rootBundle.loadString(SkeletonDemoScreen.assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    // Polymorphic deserialization relies on registerFormComponents() having run
    // at app startup (see main.dart). FormPackage.fromJson resolves elements via
    // the FormElementRegistry.
    final package = gtmobile.FormPackage.fromJson(json);
    // Retained so submit can resolve + upload image-question attachments.
    _package = package;
    return package;
  }

  Future<void> _handleComplete(gtmobile.FormState state) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final navigator = Navigator.of(context);
    try {
      final responseId = await _submissionService.submit(
        formType: 'skeleton_demo',
        formDefinitionId: state.formDefinitionId,
        formDefinitionVersion: state.schemaVersion ?? 1,
        responseJson: state.toJson(),
        package: _package,
      );

      if (!mounted) return;
      ApmFeedback.success(
        context,
        'Skeleton form submitted (responseId: $responseId).',
        category: 'GenericForms/Skeleton',
      );
      navigator.maybePop();
    } on GenericAttachmentUploadException catch (e) {
      // Photos failed to upload — keep the draft/local images, abort submit.
      if (!mounted) return;
      ApmFeedback.error(
        context,
        e.message,
        category: 'GenericForms/Skeleton',
        logMessage: 'Skeleton attachment upload failed: {Error}',
        logArgs: [e.toString()],
      );
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Skeleton submit failed. See logs for details.',
        category: 'GenericForms/Skeleton',
        logMessage: 'Skeleton submit threw: {Error}',
        logArgs: [e.toString()],
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<gtmobile.FormPackage>(
      future: _packageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          ApmLogger.warning(
            'Failed to load skeleton FormPackage: {Error}',
            args: [snapshot.error.toString()],
            category: 'GenericForms/Skeleton',
          );
          return Scaffold(
            appBar: AppBar(title: const Text('Skeleton Demo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the skeleton form definition.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final package = snapshot.data!;
        return Stack(
          children: [
            gtmobile.GTDeclarativeFormView(
              package: package,
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
      },
    );
  }
}
