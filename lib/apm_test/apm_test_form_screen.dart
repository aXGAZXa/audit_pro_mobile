import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app/app_scaffold.dart';
import '../auth/auth_session.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';
import 'apm_test_form_fields.dart';
import 'apm_test_forms_api.dart';

class ApmTestFormScreen extends StatefulWidget {
  const ApmTestFormScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ApmTestFormScreen> createState() => _ApmTestFormScreenState();
}

class _ApmTestFormScreenState extends State<ApmTestFormScreen> {
  static const _uuid = Uuid();

  final _api = ApmTestFormsApi();
  final _formKey = GlobalKey<FormState>();
  final _formNameController = TextEditingController(text: 'mobile_smoke_test');
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _formNameController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = widget.session.state.value;
    if (auth == null) {
      ApmFeedback.error(
        context,
        'You must be signed in before submitting.',
        category: 'ApmTest',
      );
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final payload = {
      'title': _titleController.text.trim(),
      'summary': _summaryController.text.trim(),
      'notes': _notesController.text.trim(),
      'submittedFrom': 'audit_pro_mobile',
      'submittedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'tenantId': auth.tenantId,
      'tenantName': auth.tenantName,
    };

    try {
      final result = await _api.submit(
        token: auth.token,
        formKey: _formNameController.text.trim(),
        clientSubmissionId: _uuid.v4(),
        payloadJson: jsonEncode(payload),
      );

      if (!mounted) return;

      if (!result.success || result.data == null) {
        ApmFeedback.error(
          context,
          result.message.isEmpty ? 'Submission failed.' : result.message,
          category: 'ApmTest',
        );
        return;
      }

      ApmFeedback.success(
        context,
        'APM test form submitted.',
        category: 'ApmTest',
        logMessage: 'APM test submission created: {SubmissionId}',
        logArgs: [result.data!.id],
      );

      _titleController.clear();
      _summaryController.clear();
      _notesController.clear();

      Navigator.of(context).pushNamed('/apm-test/submissions');
    } catch (e, st) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Submission failed: $e',
        category: 'ApmTest',
        error: e,
        stackTrace: st,
      );
      ApmLogger.error(
        'APM test submission threw: {Error}',
        args: [e.toString()],
        category: 'ApmTest',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'APM Test Feature',
      session: widget.session,
      showScreenTitle: true,
      actions: [
        IconButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pushNamed('/apm-test/submissions'),
          icon: const Icon(Icons.list_alt),
          tooltip: 'View submissions',
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ApmTestFormFields(
          formKey: _formKey,
          formNameController: _formNameController,
          titleController: _titleController,
          summaryController: _summaryController,
          notesController: _notesController,
          introText:
              'Development-only mobile test form used to validate tenant-scoped submission flow.',
          submitLabel: _isSubmitting ? 'Submitting...' : 'Submit',
          submitIcon: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          isBusy: _isSubmitting,
          onSubmit: _submit,
        ),
      ),
    );
  }
}
