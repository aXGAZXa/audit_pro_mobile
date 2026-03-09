import 'package:flutter/material.dart';

import '../../../components/entity_card.dart';
import '../../../components/form_widgets.dart';
import 'hna_unsafe_report_details_screen.dart';

class HnaUnsafeReportsScreen extends StatefulWidget {
  final Map<String, dynamic> unsafeJson;
  final ValueChanged<Map<String, dynamic>> onUnsafeChanged;
  final VoidCallback onBack;

  const HnaUnsafeReportsScreen({
    super.key,
    required this.unsafeJson,
    required this.onUnsafeChanged,
    required this.onBack,
  });

  @override
  State<HnaUnsafeReportsScreen> createState() => _HnaUnsafeReportsScreenState();
}

class _HnaUnsafeReportsScreenState extends State<HnaUnsafeReportsScreen> {
  late Map<String, dynamic> _unsafeJson;

  @override
  void initState() {
    super.initState();
    _unsafeJson = _normalizeUnsafeJson(widget.unsafeJson);
  }

  @override
  void didUpdateWidget(covariant HnaUnsafeReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.unsafeJson, oldWidget.unsafeJson)) {
      _unsafeJson = _normalizeUnsafeJson(widget.unsafeJson);
    }
  }

  Map<String, dynamic> _normalizeUnsafeJson(Map<String, dynamic> raw) {
    return _nextUnsafeJson(base: raw);
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is List<Map<String, dynamic>>) return value;
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _nextUnsafeJson({
    required Map<String, dynamic> base,
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? unsafeObservations,
    List<Map<String, dynamic>>? unreportedUnsafeObservations,
  }) {
    final out = Map<String, dynamic>.from(base);

    if (unsafeObservations != null) {
      out['unsafeObservations'] = unsafeObservations;
    } else {
      out['unsafeObservations'] = _asListOfMaps(out['unsafeObservations']);
    }

    if (reports != null) {
      out['unsafeReports'] = reports;
    } else {
      out['unsafeReports'] = _asListOfMaps(out['unsafeReports']);
    }

    if (unreportedUnsafeObservations != null) {
      out['unreportedUnsafeObservations'] = unreportedUnsafeObservations;
    } else {
      out['unreportedUnsafeObservations'] = _asListOfMaps(
        out['unreportedUnsafeObservations'],
      );
    }

    return out;
  }

  void _applyUnsafeChanged(Map<String, dynamic> nextUnsafe) {
    setState(() {
      _unsafeJson = _normalizeUnsafeJson(nextUnsafe);
    });
    widget.onUnsafeChanged(nextUnsafe);
  }

  List<Map<String, dynamic>> get _unsafeObservations {
    return _asListOfMaps(_unsafeJson['unsafeObservations']);
  }

  List<Map<String, dynamic>> get _unreportedUnsafeObservations {
    return _asListOfMaps(_unsafeJson['unreportedUnsafeObservations']);
  }

  List<Map<String, dynamic>> get _reports {
    return _asListOfMaps(_unsafeJson['unsafeReports']);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  int _observationCountForReport(Map<String, dynamic> report) {
    final ids = report['observationIds'] ?? report['observation_ids'];
    if (ids is List) return ids.length;
    return 0;
  }

  Future<void> _createNewReport() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => HnaUnsafeReportDetailsScreen(
          report: null,
          unsafeObservationsJson: _unsafeObservations,
          unreportedUnsafeObservationsJson: _unreportedUnsafeObservations,
          onBack: () => Navigator.pop(context),
          onSave: (report) => Navigator.pop(context, report),
        ),
      ),
    );

    if (result == null) return;

    final nextReports = [..._reports, result];
    final nextUnsafe = _recomputeUnreported(
      unsafeObservations: _unsafeObservations,
      unreportedUnsafeObservations: _unreportedUnsafeObservations,
      reports: nextReports,
    );

    _applyUnsafeChanged(
      _nextUnsafeJson(
        base: _unsafeJson,
        reports: nextReports,
        unsafeObservations: nextUnsafe.safe,
        unreportedUnsafeObservations: nextUnsafe.unreported,
      ),
    );
  }

  Future<void> _editReport(Map<String, dynamic> report) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => HnaUnsafeReportDetailsScreen(
          report: report,
          unsafeObservationsJson: _unsafeObservations,
          unreportedUnsafeObservationsJson: _unreportedUnsafeObservations,
          onBack: () => Navigator.pop(context),
          onSave: (updated) => Navigator.pop(context, updated),
        ),
      ),
    );

    if (result == null) return;

    final id = (report['id'] ?? '').toString();
    final nextReports = _reports
        .map((r) => (r['id'] ?? '').toString() == id ? result : r)
        .toList(growable: false);

    final nextUnsafe = _recomputeUnreported(
      unsafeObservations: _unsafeObservations,
      unreportedUnsafeObservations: _unreportedUnsafeObservations,
      reports: nextReports,
    );

    _applyUnsafeChanged(
      _nextUnsafeJson(
        base: _unsafeJson,
        reports: nextReports,
        unsafeObservations: nextUnsafe.safe,
        unreportedUnsafeObservations: nextUnsafe.unreported,
      ),
    );
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
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

    if (confirmed != true) return;

    final id = (report['id'] ?? '').toString();
    final nextReports = _reports
        .where((r) => (r['id'] ?? '').toString() != id)
        .toList(growable: false);

    final nextUnsafe = _recomputeUnreported(
      unsafeObservations: _unsafeObservations,
      unreportedUnsafeObservations: _unreportedUnsafeObservations,
      reports: nextReports,
    );

    _applyUnsafeChanged(
      _nextUnsafeJson(
        base: _unsafeJson,
        reports: nextReports,
        unsafeObservations: nextUnsafe.safe,
        unreportedUnsafeObservations: nextUnsafe.unreported,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report deleted')));
  }

  ({List<Map<String, dynamic>> safe, List<Map<String, dynamic>> unreported})
  _recomputeUnreported({
    required List<Map<String, dynamic>> unsafeObservations,
    required List<Map<String, dynamic>> unreportedUnsafeObservations,
    required List<Map<String, dynamic>> reports,
  }) {
    final all = <Map<String, dynamic>>[
      ...unsafeObservations,
      ...unreportedUnsafeObservations,
    ];

    final reportedIds = <String>{};
    for (final r in reports) {
      final ids = r['observationIds'] ?? r['observation_ids'];
      if (ids is List) {
        for (final x in ids) {
          final s = x?.toString().trim();
          if (s != null && s.isNotEmpty) reportedIds.add(s);
        }
      }
    }

    final nextReported = <Map<String, dynamic>>[];
    final nextUnreported = <Map<String, dynamic>>[];

    for (final o in all) {
      final id = o['id']?.toString().trim();
      if (id != null && id.isNotEmpty && reportedIds.contains(id)) {
        nextReported.add(o);
      } else {
        nextUnreported.add(o);
      }
    }

    return (safe: nextReported, unreported: nextUnreported);
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsafe Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unsafe Reports',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
            child: reports.isEmpty
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
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final observationCount = _observationCountForReport(
                        report,
                      );

                      final createdAt =
                          (report['createdAt'] ?? report['created_at'])
                              ?.toString();

                      return AppEntityCard(
                        title: 'Unsafe Report',
                        details: [
                          AppEntityDetail(
                            icon: Icons.warning_amber,
                            label:
                                '$observationCount observation${observationCount != 1 ? 's' : ''}',
                            valueColor: Theme.of(context).colorScheme.secondary,
                          ),
                          AppEntityDetail(
                            icon: Icons.calendar_today,
                            label: 'Created: ${_formatDate(createdAt)}',
                          ),
                        ],
                        onTap: () => _editReport(report),
                        onDelete: () => _deleteReport(report),
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
