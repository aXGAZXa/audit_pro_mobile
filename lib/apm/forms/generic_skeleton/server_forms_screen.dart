import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'generic_form_attachment_upload_service.dart';
import 'generic_form_submission_service.dart';

/// Renders a fetched [gtmobile.FormPackage] and submits the generic envelope on completion — the shared
/// CREATE path used by Home (live forms), the Developer page (dev forms) and the `form:<id>` route. The
/// old debug "Server Forms (beta)" list that lived here was removed; this is generic render infra only.
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
