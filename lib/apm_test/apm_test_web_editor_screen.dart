import 'dart:convert';

import 'package:flutter/material.dart';

import '../logging/apm_feedback.dart';
import 'apm_test_form_fields.dart';
import 'apm_test_forms_api.dart';
import 'apm_test_models.dart';

class ApmTestWebEditorScreen extends StatefulWidget {
  const ApmTestWebEditorScreen({
    super.key,
    required this.submissionId,
    required this.token,
  });

  final String submissionId;
  final String token;

  @override
  State<ApmTestWebEditorScreen> createState() => _ApmTestWebEditorScreenState();
}

class _ApmTestWebEditorScreenState extends State<ApmTestWebEditorScreen> {
  final _api = ApmTestFormsApi();
  final _formKey = GlobalKey<FormState>();
  final _formNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  ApmTestFormSubmission? _submission;
  List<ApmTestFormSubmissionRevision> _revisions = const [];
  Map<String, dynamic> _loadedPayload = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _formNameController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final submissionResult = await _api.getSubmission(
        token: widget.token,
        submissionId: widget.submissionId,
      );
      if (!submissionResult.success || submissionResult.data == null) {
        throw Exception(
          submissionResult.message.isEmpty
              ? 'Failed to load submission.'
              : submissionResult.message,
        );
      }

      final revisionsResult = await _api.getRevisions(
        token: widget.token,
        submissionId: widget.submissionId,
        take: 50,
      );
      if (!revisionsResult.success) {
        throw Exception(
          revisionsResult.message.isEmpty
              ? 'Failed to load revisions.'
              : revisionsResult.message,
        );
      }

      final submission = submissionResult.data!;
      final payload = _decodePayload(submission.payloadJson);

      if (!mounted) return;
      setState(() {
        _submission = submission;
        _revisions = revisionsResult.data ?? const [];
        _loadedPayload = payload;
        _formNameController.text = submission.formKey;
        _titleController.text = (payload['title'] ?? '').toString();
        _summaryController.text = (payload['summary'] ?? '').toString();
        _notesController.text = (payload['notes'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final current = _submission;
    if (current == null) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final normalizedJson = jsonEncode(_buildUpdatedPayload());

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await _api.updateSubmission(
        token: widget.token,
        submissionId: current.id,
        payloadJson: normalizedJson,
      );
      if (!mounted) return;

      if (!result.success || result.data == null) {
        ApmFeedback.error(
          context,
          result.message.isEmpty ? 'Save failed.' : result.message,
        );
        setState(() {
          _saving = false;
        });
        return;
      }

      ApmFeedback.success(context, 'Submission updated.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(context, 'Save failed: $e');
      setState(() {
        _saving = false;
      });
    }
  }

  Map<String, dynamic> _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _buildUpdatedPayload() {
    return {
      ..._loadedPayload,
      'title': _titleController.text.trim(),
      'summary': _summaryController.text.trim(),
      'notes': _notesController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final submission = _submission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('APM Test Web Editor'),
        actions: [
          IconButton(
            onPressed: (_loading || _saving) ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          FilledButton.icon(
            onPressed: (_loading || _saving || submission == null)
                ? null
                : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : submission == null
          ? const Center(child: Text('Submission not found.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                final editor = _EditorPane(
                  formKey: _formKey,
                  submission: submission,
                  formNameController: _formNameController,
                  titleController: _titleController,
                  summaryController: _summaryController,
                  notesController: _notesController,
                  isSaving: _saving,
                  onSave: _save,
                );
                final revisions = _RevisionPane(revisions: _revisions);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: editor),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: revisions),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(height: 520, child: editor),
                    const SizedBox(height: 16),
                    SizedBox(height: 320, child: revisions),
                  ],
                );
              },
            ),
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.formKey,
    required this.submission,
    required this.formNameController,
    required this.titleController,
    required this.summaryController,
    required this.notesController,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final ApmTestFormSubmission submission;
  final TextEditingController formNameController;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController notesController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Submission: ${submission.id}'),
              Text('Form: ${submission.formKey}'),
              Text('Revision: ${submission.revision}'),
              Text('By: ${submission.submittedByEmail}'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: ApmTestFormFields(
                formKey: formKey,
                formNameController: formNameController,
                titleController: titleController,
                summaryController: summaryController,
                notesController: notesController,
                readOnlyFormKey: true,
                introText:
                    'This hosted editor reuses the same APM test form fields as the mobile submit experience.',
                submitLabel: isSaving ? 'Saving...' : 'Save changes',
                submitIcon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                isBusy: isSaving,
                onSubmit: onSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionPane extends StatelessWidget {
  const _RevisionPane({required this.revisions});

  final List<ApmTestFormSubmissionRevision> revisions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revision History',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: revisions.isEmpty
                ? const Center(child: Text('No revisions yet.'))
                : ListView.separated(
                    itemCount: revisions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final revision = revisions[index];
                      return ListTile(
                        dense: true,
                        title: Text('Revision ${revision.revision}'),
                        subtitle: Text(
                          '${revision.editedByType} • ${revision.editedByEmail ?? 'unknown'}\n${revision.editedAtUtc.toLocal()}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
