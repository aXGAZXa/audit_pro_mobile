import 'package:flutter/material.dart';

import '../app/app_scaffold.dart';
import '../auth/auth_session.dart';
import '../logging/apm_logger.dart';
import '../apm/forms/condition_report/condition_report_definition.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_screen.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_requests_service.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_session_snapshot_hydrator.dart';
import '../apm/forms/services/forms_edit_sessions_service.dart';
import '../apm/database/database_helper.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  final _db = DatabaseHelper.instance;
  final _editRequestsService = FormsEditRequestsService();
  final _editSessionsService = FormsEditSessionsService();
  final _hydrator = FormEditSessionSnapshotHydrator();

  static const Duration _retention = Duration(days: 7);

  bool _busy = true;
  bool _checkingEditRequests = false;
  String _status = '';
  List<Map<String, dynamic>> _items = const [];

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
      final sent = forms.where((f) => f['status'] == 'sent').toList()
        ..sort((a, b) {
          final aUpdated = a['updated_at']?.toString() ?? '';
          final bUpdated = b['updated_at']?.toString() ?? '';
          return bUpdated.compareTo(aUpdated);
        });

      setState(() {
        _items = sent;
        _status = sent.isEmpty
            ? 'No completed submissions on this device.'
            : '';
      });
    } catch (e, st) {
      ApmLogger.warning(
        'Submissions load failed: {Error}',
        args: [e.toString()],
        category: 'Submissions',
        error: e,
        stackTrace: st,
      );
      setState(() {
        _status = 'Unable to load submissions.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _checkForEditRequests() async {
    if (_checkingEditRequests) return;

    final token = widget.session.state.value?.token;
    if (token == null || token.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      }
      return;
    }

    setState(() {
      _checkingEditRequests = true;
    });

    try {
      ApmLogger.info(
        'Checking for edit requests',
        category: 'APM/EditRequests',
      );
      final pending = await _editRequestsService.getPending(token: token);
      if (!mounted) return;

      ApmLogger.info(
        'Edit requests check OK (count: {Count})',
        args: [pending.length],
        category: 'APM/EditRequests',
      );

      if (pending.isNotEmpty) {
        ApmLogger.debug(
          'Edit requests ids (first up to 5): {Ids}',
          args: [pending.take(5).map((r) => r.editRequestId).join(', ')],
          category: 'APM/EditRequests',
        );
      }

      if (pending.isEmpty) {
        ApmLogger.info(
          'No pending edit requests returned',
          category: 'APM/EditRequests',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No edit requests found.')),
        );
        return;
      }

      final currentTenantId = (widget.session.state.value?.tenantId ?? '')
          .trim();
      final r = pending.first;

      ApmLogger.debug(
        'Using first pending edit request: editRequestId={EditRequestId}, submissionId={SubmissionId}, tenantId={TenantId}, currentTenantId={CurrentTenantId}',
        args: [r.editRequestId, r.submissionId, r.tenantId, currentTenantId],
        category: 'APM/EditRequests',
      );

      final sameTenant =
          currentTenantId.isNotEmpty && r.tenantId.trim() == currentTenantId;

      ApmLogger.info(
        'Edit request tenant match: {SameTenant}',
        args: [sameTenant],
        category: 'APM/EditRequests',
      );

      final requestedAt = r.requestedAtUtc;
      final requestedAtLabel = requestedAt == null
          ? ''
          : _formatIsoDateTime(context, requestedAt.toIso8601String());

      final message = r.message.trim();
      final managerLabel = r.managerName.trim().isEmpty
          ? 'A manager'
          : r.managerName.trim();
      final tenantLabel = r.tenantName.trim().isEmpty
          ? 'your company'
          : r.tenantName.trim();

      final info = [
        '$managerLabel at $tenantLabel has requested changes to your submitted Heat Network Assessment.',
        if (requestedAtLabel.isNotEmpty) 'Requested: $requestedAtLabel',
        if (message.isNotEmpty) 'Message: $message',
        if (!sameTenant)
          'To edit this submission, please log into $tenantLabel via the Settings page.',
      ].join('\n\n');

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              pending.length == 1
                  ? 'Edit requested'
                  : 'Edit requested (${pending.length})',
            ),
            content: Text(info),
            actions: [
              if (sameTenant)
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _startEditNow(token: token, request: r);
                  },
                  child: const Text('Edit now'),
                ),
              if (!sameTenant)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, '/settings');
                  },
                  child: const Text('Open Settings'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Edit requests check failed: {Error}',
        args: [e.toString()],
        category: 'APM/EditRequests',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _checkingEditRequests = false;
        });
      }
    }
  }

  Future<void> _startEditNow({
    required String token,
    required FormPendingEditRequest request,
  }) async {
    setState(() {
      _checkingEditRequests = true;
    });

    try {
      final start = await _editSessionsService.start(
        token: token,
        editRequestId: request.editRequestId,
      );

      final snapshot = await _editSessionsService.snapshot(
        token: token,
        sessionToken: start.sessionToken,
      );

      final newFormId = await _hydrator.createDraftFromSnapshot(
        assessment: snapshot.formPayload,
        token: token,
        sessionToken: start.sessionToken,
        editRequestId: request.editRequestId,
        submissionId: snapshot.submissionId.isNotEmpty
            ? snapshot.submissionId
            : start.submissionId,
        submittedAtUtc: snapshot.submittedAtUtc,
        expiresAtUtc: start.expiresAtUtc,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna'),
          builder: (_) => HeatNetworkAssessmentScreen(formId: newFormId),
        ),
      );

      await _load();
    } catch (e, st) {
      ApmLogger.warning(
        'Start edit flow failed: {Error}',
        args: [e.toString()],
        category: 'APM/EditFlow',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _checkingEditRequests = false;
        });
      }
    }
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
    return v?.toString().trim() ?? '';
  }

  Map<String, dynamic> _readFormData(Map<String, dynamic> form) {
    final raw = form['form_data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _readSubmissionSummary(Map<String, dynamic> fd) {
    final raw = fd['submissionSummary'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  String _formatIsoDateTime(BuildContext context, String iso) {
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

  ({String title, IconData icon, MaterialColor color}) _formTypePresentation(
    String formType,
  ) {
    if (formType == kConditionReportFormType) {
      return (
        title: 'Condition Report',
        icon: Icons.fact_check,
        color: Colors.teal,
      );
    }

    return (
      title: 'Heat Network Assessment',
      icon: Icons.network_check,
      color: Colors.deepOrange,
    );
  }

  String _formatDueDateLabel(DateTime dueAt) {
    final now = DateTime.now();
    final dueDay = DateUtils.dateOnly(dueAt);
    final today = DateUtils.dateOnly(now);

    final days = dueDay.difference(today).inDays;
    if (days <= 0) return 'Auto-deletes today';
    if (days == 1) return 'Auto-deletes tomorrow';
    return 'Auto-deletes in $days days';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Submissions',
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
          : _items.isEmpty
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkingEditRequests
                          ? null
                          : _checkForEditRequests,
                      icon: _checkingEditRequests
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_notifications),
                      label: const Text('Check for edit requests'),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(_status.isEmpty ? 'No submissions.' : _status),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkingEditRequests
                          ? null
                          : _checkForEditRequests,
                      icon: _checkingEditRequests
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_notifications),
                      label: const Text('Check for edit requests'),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final formType =
                          item['form_type']?.toString().trim() ??
                          kHeatNetworkAssessmentFormType;
                      final typeUi = _formTypePresentation(formType);
                      final updatedAt =
                          item['updated_at']?.toString().trim() ?? '';
                      final uuid = item['uuid']?.toString().trim() ?? '';

                      final fd = _readFormData(item);
                      final summary = _readSubmissionSummary(fd);

                      final client = _readString(fd, 'client').isNotEmpty
                          ? _readString(fd, 'client')
                          : _readString(fd, 'clientName');

                      final sentAt =
                          (summary['sentAt'] ?? summary['submittedAt'] ?? '')
                              .toString()
                              .trim();
                      final effectiveSubmittedIso = sentAt.isNotEmpty
                          ? sentAt
                          : updatedAt;

                      final submittedAtDt = DateTime.tryParse(
                        effectiveSubmittedIso,
                      );
                      final retentionLabel = submittedAtDt == null
                          ? 'Auto-deletes after 7 days.'
                          : _formatDueDateLabel(submittedAtDt.add(_retention));

                      final ref = (summary['friendlyRef'] ?? '')
                          .toString()
                          .trim();
                      final friendlyRef = ref.isNotEmpty
                          ? ref
                          : (effectiveSubmittedIso.isEmpty || uuid.isEmpty)
                          ? ''
                          : _buildFriendlyRefFallback(
                              formType: formType,
                              iso: effectiveSubmittedIso,
                              uuid: uuid,
                            );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: typeUi.color.shade400.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    typeUi.icon,
                                    size: 32,
                                    color: typeUi.color.shade400,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              typeUi.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _statusChip(context, 'Submitted'),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        [
                                          if (client.isNotEmpty)
                                            'Client: $client',
                                          if (friendlyRef.isNotEmpty)
                                            'Reference: $friendlyRef',
                                          if (effectiveSubmittedIso.isNotEmpty)
                                            'Submitted: ${_formatIsoDateTime(context, effectiveSubmittedIso)}',
                                          retentionLabel,
                                        ].join('\n'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
