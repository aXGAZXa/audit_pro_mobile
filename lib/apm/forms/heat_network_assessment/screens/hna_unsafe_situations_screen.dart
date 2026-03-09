import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../../components/form_widgets.dart';

import 'hna_unsafe_reports_screen.dart';

class HNAUnsafeSituationsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Map<String, dynamic> unsafeJson;
  final ValueChanged<Map<String, dynamic>> onUnsafeChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const HNAUnsafeSituationsScreen({
    super.key,
    required this.formData,
    required this.unsafeJson,
    required this.onUnsafeChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<HNAUnsafeSituationsScreen> createState() =>
      _HNAUnsafeSituationsScreenState();
}

class _HNAUnsafeSituationsScreenState extends State<HNAUnsafeSituationsScreen> {
  List<Map<String, dynamic>> _unsafeSituations = [];
  Map<String, bool> _reportingStatus = {}; // observationId -> isReported
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromJson();
  }

  @override
  void didUpdateWidget(covariant HNAUnsafeSituationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unsafeJson != widget.unsafeJson) {
      _hydrateFromJson();
    }
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

  void _hydrateFromJson() {
    setState(() => _isLoading = true);

    try {
      final unsafeObservations = _asListOfMaps(
        widget.unsafeJson['unsafeObservations'],
      );
      final unreportedUnsafe = _asListOfMaps(
        widget.unsafeJson['unreportedUnsafeObservations'],
      );

      final byId = <String, Map<String, dynamic>>{};
      var tmpIndex = 0;
      for (final obs in [...unsafeObservations, ...unreportedUnsafe]) {
        final id = obs['id'];
        final key = (id == null || id.toString().trim().isEmpty)
            ? 'tmp_${tmpIndex++}'
            : id.toString();
        byId[key] = obs;
      }

      final reports = _asListOfMaps(widget.unsafeJson['unsafeReports']);
      final reportedObsIds = <String>{};
      for (final r in reports) {
        final ids = r['observationIds'] ?? r['observation_ids'];
        if (ids is List) {
          for (final x in ids) {
            final s = x?.toString().trim();
            if (s != null && s.isNotEmpty) reportedObsIds.add(s);
          }
        }
      }

      final situations = byId.values.toList(growable: false);
      final status = <String, bool>{};
      for (final s in situations) {
        final id = s['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        status[id] = reportedObsIds.contains(id);
      }

      if (mounted) {
        setState(() {
          _unsafeSituations = situations;
          _reportingStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error hydrating unsafe situations from JSON: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _reportedCount =>
      _reportingStatus.values.where((reported) => reported).length;
  int get _totalCount => _unsafeSituations.length;

  Future<void> _saveAndContinue() async {
    // Check if all unsafe observations have been reported
    if (_unsafeSituations.isNotEmpty && _reportedCount < _totalCount) {
      final unreportedCount = _totalCount - _reportedCount;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Incomplete Reporting'),
            ],
          ),
          content: Text(
            '$unreportedCount unsafe observation${unreportedCount != 1 ? 's' : ''} '
            '${unreportedCount != 1 ? 'have' : 'has'} not been included in any report.\n\n'
            'All unsafe situations must be documented in at least one report before proceeding.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    widget.onNext();
  }

  Future<void> _showObservationDetails(Map<String, dynamic> observation) async {
    final images =
        observation['images'] as List<dynamic>? ??
        observation['imagePaths'] as List<dynamic>? ??
        [];

    // Build display label from context
    String displayLabel;
    final assetId = observation['asset_id'];
    if (assetId != null) {
      // Asset observation
      final assetType = observation['asset_type'] ?? '';
      final assetMakeModel = observation['asset_make_model'] ?? '';
      displayLabel = assetMakeModel.isNotEmpty
          ? '$assetType: $assetMakeModel'
          : assetType;
    } else {
      // Question observation
      final sectionName = observation['section_name'];
      final questionText = observation['question_text'];
      if (sectionName != null && questionText != null) {
        displayLabel = '$sectionName: $questionText';
      } else if (questionText != null) {
        displayLabel = questionText;
      } else {
        // Fallback to question_reference if no context
        displayLabel = observation['question_reference'] ?? 'Observation';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(observation['notes'] ?? 'No details'),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Images',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: images.map((imgPath) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppResolvedImage(
                        imagePath: imgPath.toString(),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReports =
        (widget.unsafeJson['unsafeReports'] is List) &&
        (widget.unsafeJson['unsafeReports'] as List).isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unsafe Situations',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_unsafeSituations.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _reportedCount == _totalCount
                                    ? Colors.green[50]
                                    : Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _reportedCount == _totalCount
                                      ? Colors.green[200]!
                                      : Colors.orange[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _reportedCount == _totalCount
                                        ? Icons.check_circle
                                        : Icons.warning_amber,
                                    color: _reportedCount == _totalCount
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reporting Status',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _reportedCount == _totalCount
                                                ? Colors.green[900]
                                                : Colors.orange[900],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_reportedCount of $_totalCount observations reported',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _reportedCount == _totalCount
                                                ? Colors.green[800]
                                                : Colors.orange[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_unsafeSituations.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No unsafe situations recorded',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _unsafeSituations.length,
                          itemBuilder: (context, index) {
                            final situation = _unsafeSituations[index];
                            final situationId =
                                situation['id']?.toString() ?? '';
                            final isReported =
                                _reportingStatus[situationId] ?? false;

                            // Build display label from context
                            String displayLabel;
                            final assetId = situation['asset_id'];
                            if (assetId != null) {
                              // Asset observation
                              final assetType = situation['asset_type'] ?? '';
                              final assetMakeModel =
                                  situation['asset_make_model'] ?? '';
                              displayLabel = assetMakeModel.isNotEmpty
                                  ? '$assetType: $assetMakeModel'
                                  : assetType;
                            } else {
                              // Question observation
                              final sectionName = situation['section_name'];
                              final questionText = situation['question_text'];
                              if (sectionName != null && questionText != null) {
                                displayLabel = '$sectionName: $questionText';
                              } else if (questionText != null) {
                                displayLabel = questionText;
                              } else {
                                // Fallback to question_reference if no context
                                displayLabel =
                                    situation['question_reference'] ??
                                    'Unknown';
                              }
                            }

                            final notes = situation['notes'] ?? 'No details';
                            final classification =
                                situation['unsafe_classification'] as String?;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                child: InkWell(
                                  onTap: () async {
                                    await _showObservationDetails(situation);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                            if (classification != null) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: classification == 'ID'
                                                      ? Colors.red[100]
                                                      : Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  classification,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        classification == 'ID'
                                                        ? Colors.red[900]
                                                        : Colors.orange[900],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isReported
                                                    ? Colors.green[100]
                                                    : Colors.orange[100],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isReported
                                                        ? Icons.check_circle
                                                        : Icons.warning_amber,
                                                    size: 12,
                                                    color: isReported
                                                        ? Colors.green[900]
                                                        : Colors.orange[900],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isReported
                                                        ? 'Reported'
                                                        : 'Needs Report',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isReported
                                                          ? Colors.green[900]
                                                          : Colors.orange[900],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unsafeSituations.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HnaUnsafeReportsScreen(
                            unsafeJson: widget.unsafeJson,
                            onUnsafeChanged: widget.onUnsafeChanged,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _hydrateFromJson();
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('View Unsafe Reports'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_unsafeSituations.isEmpty && hasReports) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HnaUnsafeReportsScreen(
                            unsafeJson: widget.unsafeJson,
                            onUnsafeChanged: widget.onUnsafeChanged,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _hydrateFromJson();
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('View Unsafe Reports'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppButton(text: 'Back', onPressed: widget.onBack),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppButton(
                        text: 'Next',
                        onPressed: _saveAndContinue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
