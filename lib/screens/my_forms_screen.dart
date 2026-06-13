import 'package:flutter/material.dart';

import '../app/app_scaffold.dart';
import '../auth/auth_session.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';
import '../apm/database/database_helper.dart';
import '../apm/forms/condition_report/condition_report_definition.dart';
import '../apm/forms/condition_report/condition_report_screen.dart';
import '../apm/forms/condition_report/cr_repository_factory.dart';
import '../apm/forms/condition_report/services/cr_submission_service.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import '../apm/forms/heat_network_assessment/services/hna_form_delete_service.dart';
import '../apm/forms/heat_network_assessment/services/hna_submission_service.dart';
import '../apm/services/app_info_service.dart';
import '../apm/services/auth_token_store.dart';
import '../hna/heat_network_assessment/heat_network_assessment_screen.dart';

class MyFormsScreen extends StatefulWidget {
  const MyFormsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<MyFormsScreen> createState() => _MyFormsScreenState();
}

class _MyFormsScreenState extends State<MyFormsScreen> {
  final _db = DatabaseHelper.instance;
  final _deleteService = HnaFormDeleteService();
  final _submissionService = HnaSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );
  final _crSubmissionService = CrSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );

  bool _busy = true;
  String _status = '';
  List<Map<String, dynamic>> _inProgress = const [];
  List<Map<String, dynamic>> _drafts = const [];
  List<Map<String, dynamic>> _pending = const [];
  int? _currentHnaDraftId;
  int? _currentCrDraftId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _status = '';
    });

    try {
      final hnaForms = await _db.getFormsByType(kHeatNetworkAssessmentFormType);
      final crForms = await _db.getFormsByType(kConditionReportFormType);
      final forms = [...hnaForms, ...crForms];

      final currentHnaId = await _db.getCurrentFormId(
        kHeatNetworkAssessmentFormType,
      );
      final currentCrId = await _db.getCurrentFormId(kConditionReportFormType);

      final allDraft = forms.where((f) => f['status'] == 'draft').toList();
      final pending = forms.where((f) => f['status'] == 'pending').toList();

      final inProgress = allDraft.where((f) {
        final id = f['id'];
        final formType = _formType(f);
        if (formType == kHeatNetworkAssessmentFormType) {
          return id == currentHnaId;
        }
        if (formType == kConditionReportFormType) return id == currentCrId;
        return false;
      }).toList();

      final otherDrafts = allDraft.where((f) {
        final id = f['id'];
        final formType = _formType(f);
        if (formType == kHeatNetworkAssessmentFormType) {
          return id != currentHnaId;
        }
        if (formType == kConditionReportFormType) return id != currentCrId;
        return true;
      }).toList();

      setState(() {
        _inProgress = inProgress;
        _drafts = otherDrafts;
        _pending = pending;
        _currentHnaDraftId = currentHnaId;
        _currentCrDraftId = currentCrId;
        _status = (allDraft.isEmpty && pending.isEmpty) ? 'No forms yet.' : '';
      });
    } catch (e, st) {
      ApmLogger.warning(
        'MyForms load failed: {Error}',
        args: [e.toString()],
        category: 'MyForms',
        error: e,
        stackTrace: st,
      );
      setState(() {
        _status = 'Unable to load forms.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete form?'),
          content: const Text(
            'This will permanently delete the form and any saved attachments on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return ok ?? false;
  }

  Future<void> _deleteForm(int formId) async {
    final ok = await _confirmDelete();
    if (!ok) return;

    try {
      setState(() => _busy = true);
      await _deleteService.deleteFormAndAttachments(formId: formId, db: _db);

      final form = await _db.getForm(formId);
      final formType = _formType(form ?? const {});
      final currentId = await _db.getCurrentFormId(formType);
      if (currentId == formId) {
        await _db.clearCurrentFormId(formType);
      }

      if (!mounted) return;
      ApmFeedback.success(context, 'Form deleted.', category: 'MyForms');
      await _load();
    } catch (e, st) {
      ApmLogger.warning(
        'Delete form failed formId=$formId: {Error}',
        args: [e.toString()],
        category: 'MyForms',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Unable to delete form.',
        category: 'MyForms',
        logMessage: 'Delete form failed: {Error}',
        logArgs: [e.toString()],
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resubmit(int formId) async {
    final auth = widget.session.state.value;
    if (auth == null) {
      ApmFeedback.info(
        context,
        'Please sign in to submit.',
        category: 'MyForms',
      );
      return;
    }

    try {
      setState(() => _busy = true);
      final form = await _db.getForm(formId);
      final formType = _formType(form ?? const {});
      if (formType == kConditionReportFormType) {
        await _crSubmissionService.submitForm(formId: formId);
      } else {
        await _submissionService.submitForm(formId: formId);
      }
      if (!mounted) return;
      ApmFeedback.success(context, 'Submitted.', category: 'MyForms');
      await _load();
    } catch (e, st) {
      ApmLogger.warning(
        'Resubmit failed formId=$formId: {Error}',
        args: [e.toString()],
        category: 'MyForms',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Submit failed. Kept in My Forms for retry.',
        category: 'MyForms',
        logMessage: 'Resubmit failed: {Error}',
        logArgs: [e.toString()],
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _statusChip(BuildContext context, String text) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(text),
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }

  String _readString(Map<String, dynamic> root, String key) {
    final v = root[key];
    final s = v?.toString().trim() ?? '';
    return s;
  }

  String _formatIsoDateTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;

    final local = parsed.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return '$date • $time';
  }

  Map<String, dynamic> _readFormData(Map<String, dynamic> form) {
    final formData = form['form_data'];
    return formData is Map
        ? Map<String, dynamic>.from(formData)
        : const <String, dynamic>{};
  }

  Map<String, dynamic> _readSubmissionSummary(Map<String, dynamic> fd) {
    final raw = fd['submissionSummary'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  String _uuidSuffix(String uuid) {
    final cleaned = uuid.replaceAll('-', '').trim();
    if (cleaned.length < 3) return 'XXX';
    return cleaned.substring(0, 3).toUpperCase();
  }

  String _buildFriendlyRefFallback({
    required String formType,
    required String iso,
    required String uuid,
  }) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';

    final yy = (parsed.year % 100).toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');

    final prefix = formType == kConditionReportFormType ? 'CR' : 'HNA';
    return '$prefix-$yy$mm$dd-$hh$min-${_uuidSuffix(uuid)}';
  }

  String _buildDraftMetadata(Map<String, dynamic> form) {
    final updatedAtRaw = form['updated_at']?.toString().trim() ?? '';
    final fd = _readFormData(form);

    final client = _readString(fd, 'client').isNotEmpty
        ? _readString(fd, 'client')
        : _readString(fd, 'clientName');

    final parts = <String>[];
    if (client.isNotEmpty) parts.add('Client: $client');

    final updatedAt = updatedAtRaw.isEmpty
        ? ''
        : _formatIsoDateTime(updatedAtRaw);
    final line2 = updatedAt.isEmpty ? '' : 'Updated: $updatedAt';

    final line1 = parts.isEmpty ? '' : parts.join(' • ');
    if (line1.isEmpty) return line2;
    if (line2.isEmpty) return line1;
    return '$line1\n$line2';
  }

  String _buildPendingMetadata(Map<String, dynamic> form) {
    final updatedAtRaw = form['updated_at']?.toString().trim() ?? '';
    final uuid = form['uuid']?.toString().trim() ?? '';
    final formType = _formType(form);
    final fd = _readFormData(form);
    final summary = _readSubmissionSummary(fd);

    final client = _readString(fd, 'client').isNotEmpty
        ? _readString(fd, 'client')
        : _readString(fd, 'clientName');

    final ref = (summary['friendlyRef'] ?? '').toString().trim();
    final friendlyRef = ref.isNotEmpty
        ? ref
        : (updatedAtRaw.isEmpty || uuid.isEmpty)
        ? ''
        : _buildFriendlyRefFallback(
            formType: formType,
            iso: updatedAtRaw,
            uuid: uuid,
          );

    final attemptedAt =
        (summary['lastAttemptAt'] ?? summary['submittedAt'] ?? '')
            .toString()
            .trim();
    final effectiveAttemptIso = attemptedAt.isNotEmpty
        ? attemptedAt
        : updatedAtRaw;
    final attemptedAtFriendly = effectiveAttemptIso.isEmpty
        ? ''
        : _formatIsoDateTime(effectiveAttemptIso);

    return [
      if (client.isNotEmpty) 'Client: $client',
      if (friendlyRef.isNotEmpty) 'Reference: $friendlyRef',
      if (attemptedAtFriendly.isNotEmpty) 'Last attempt: $attemptedAtFriendly',
    ].join('\n');
  }

  Widget _buildAppCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String status,
    required String metadata,
    VoidCallback? onTap,
    List<Widget> actions = const [],
    Widget? trailing,
  }) {
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(context, status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  metadata,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );

    return Card(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> form) {
    final formId = form['id'] as int;
    final formType = _formType(form);
    final isCurrent = formType == kConditionReportFormType
        ? _currentCrDraftId == formId
        : _currentHnaDraftId == formId;

    final isCr = formType == kConditionReportFormType;
    final title = isCr ? 'Condition Report' : 'Heat Network Assessment';
    final icon = isCr ? Icons.assignment : Icons.network_check;
    final color = isCr ? Colors.blue.shade400 : Colors.deepOrange.shade400;

    return _buildAppCard(
      context,
      icon: icon,
      color: color,
      title: title,
      status: isCurrent ? 'In Progress' : 'Draft',
      metadata: _buildDraftMetadata(form),
      onTap: _busy
          ? null
          : () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  settings: RouteSettings(
                    name: isCr ? '/condition-report' : '/hna',
                  ),
                  builder: (_) => isCr
                      ? ConditionReportScreen(
                          formId: formId,
                          repo: createCrMobileRepository(),
                        )
                      : HeatNetworkAssessmentScreen(formId: formId),
                ),
              );
              await _load();
            },
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : () => _deleteForm(formId),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> form) {
    final formId = form['id'] as int;
    final formType = _formType(form);
    final isCr = formType == kConditionReportFormType;
    final title = isCr ? 'Condition Report' : 'Heat Network Assessment';
    final icon = isCr ? Icons.assignment : Icons.network_check;
    final color = isCr ? Colors.blue.shade400 : Colors.deepOrange.shade400;

    return _buildAppCard(
      context,
      icon: icon,
      color: color,
      title: title,
      status: 'Needs resubmit',
      metadata: _buildPendingMetadata(form),
      onTap: null,
      actions: [
        FilledButton(
          onPressed: _busy ? null : () => _resubmit(formId),
          child: const Text('Resubmit'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _deleteForm(formId),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    );
  }

  String _formType(Map<String, dynamic> form) {
    return (form['form_type'] ?? kHeatNetworkAssessmentFormType).toString();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Forms',
      showScreenTitle: true,
      session: widget.session,
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : (_inProgress.isEmpty && _drafts.isEmpty && _pending.isEmpty)
          ? Center(child: Text(_status.isEmpty ? 'No forms yet.' : _status))
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (_inProgress.isNotEmpty)
                  _sectionHeader(context, 'In Progress'),
                ..._inProgress.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDraftCard(f),
                  ),
                ),
                if (_drafts.isNotEmpty) _sectionHeader(context, 'Drafts'),
                ..._drafts.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDraftCard(f),
                  ),
                ),
                if (_pending.isNotEmpty)
                  _sectionHeader(context, 'Needs Resubmit'),
                ..._pending.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildPendingCard(f),
                  ),
                ),
              ],
            ),
    );
  }
}
