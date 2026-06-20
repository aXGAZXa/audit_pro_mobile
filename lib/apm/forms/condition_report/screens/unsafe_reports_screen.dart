import 'package:audit_pro_mobile/apm/components/entity_card.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/shared/data/form_repository.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:flutter/material.dart';

import 'unsafe_details_screen.dart';

class UnsafeReportsScreen extends StatefulWidget {
  final int formId;
  final VoidCallback onBack;
  final FormRepository? repo;

  const UnsafeReportsScreen({
    super.key,
    required this.formId,
    required this.onBack,
    this.repo,
  });

  @override
  State<UnsafeReportsScreen> createState() => _UnsafeReportsScreenState();
}

class _UnsafeReportsScreenState extends State<UnsafeReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final reports = await DatabaseHelper.instance.getUnsafeReports(
        widget.formId,
      );

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ApmFeedback.error(context, 'Error loading reports: $e');
      }
    }
  }

  Future<void> _createNewReport() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UnsafeDetailsScreen(
          formId: widget.formId,
          repo: widget.repo,
          onBack: () => Navigator.pop(context, false),
          onSave: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _viewReport(int reportId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UnsafeDetailsScreen(
          formId: widget.formId,
          reportId: reportId,
          repo: widget.repo,
          onBack: () => Navigator.pop(context, false),
          onSave: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _deleteReport(int reportId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (widget.repo != null) {
          await widget.repo!.deleteCollectionItem('unsafeReports', reportId);
        } else {
          await DatabaseHelper.instance.deleteUnsafeReport(reportId);
        }
        _loadReports();
        if (mounted) {
          ApmFeedback.success(context, 'Report deleted');
        }
      } catch (e) {
        if (mounted) {
          ApmFeedback.error(context, 'Error deleting report: $e');
        }
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsafe Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unsafe Reports',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Create New Report',
                        icon: Icons.add,
                        onPressed: _createNewReport,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _reports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Reports Yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            final reportId = report['id'] as int;
                            final observationCount =
                                report['observation_count'] as int? ?? 0;
                            final createdAt = report['created_at'] as String?;

                            return AppEntityCard(
                              title: 'Unsafe Report',
                              details: [
                                AppEntityDetail(
                                  icon: Icons.warning_amber,
                                  label:
                                      '$observationCount observation${observationCount != 1 ? 's' : ''}',
                                  valueColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                AppEntityDetail(
                                  icon: Icons.calendar_today,
                                  label: 'Created: ${_formatDate(createdAt)}',
                                ),
                              ],
                              onTap: () => _viewReport(reportId),
                              onDelete: () => _deleteReport(reportId),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AppButton(
                      text: 'Return',
                      icon: Icons.arrow_back,
                      onPressed: widget.onBack,
                      fullWidth: true,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
