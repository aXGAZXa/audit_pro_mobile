import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class HnaObservationsListScreen extends StatefulWidget {
  const HnaObservationsListScreen({
    super.key,
    required this.observationsJson,
    required this.onObservationsChanged,
    required this.questionReference,
    required this.questionText,
    required this.sectionName,
    this.assetId,
    this.assetType,
    this.assetMakeModel,
  });

  final List<Map<String, dynamic>> observationsJson;
  final void Function(List<Map<String, dynamic>> next) onObservationsChanged;

  final String questionReference;
  final String questionText;
  final String sectionName;

  final String? assetId;
  final String? assetType;
  final String? assetMakeModel;

  @override
  State<HnaObservationsListScreen> createState() =>
      _HnaObservationsListScreenState();
}

class _HnaObservationsListScreenState extends State<HnaObservationsListScreen> {
  bool _isWorking = false;

  late List<Map<String, dynamic>> _observations;

  @override
  void initState() {
    super.initState();
    _observations = widget.observationsJson
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);
  }

  @override
  void didUpdateWidget(covariant HnaObservationsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent replaces the observations list instance, mirror it.
    if (!identical(oldWidget.observationsJson, widget.observationsJson)) {
      _observations = widget.observationsJson
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    }
  }

  List<Map<String, dynamic>> get _all => _observations;

  List<Map<String, dynamic>> get _filtered {
    final ref = widget.questionReference.trim();
    if (ref.isEmpty) return <Map<String, dynamic>>[];

    final out = <Map<String, dynamic>>[];
    for (final o in _all) {
      final oRef = (o['questionReference'] ?? o['question_reference'] ?? '')
          .toString()
          .trim();
      if (oRef == ref) {
        out.add(Map<String, dynamic>.from(o));
      }
    }
    return out;
  }

  Future<void> _addObservation() async {
    final result = await Navigator.pushNamed(
      context,
      '/add-observation',
      arguments: {
        'title': widget.questionText,
        'existingObservation': null,
        'questionReference': widget.questionReference,
        'assetType': widget.assetType,
        'assetId': widget.assetId,
        'assetMakeModel': widget.assetMakeModel,
        'sectionName': widget.sectionName,
      },
    );

    if (!mounted) return;
    if (result is! Map<String, dynamic>) return;

    await _upsertFromEditorResult(result);
  }

  Future<void> _editObservation(Map<String, dynamic> observation) async {
    final id = (observation['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final imagePaths = (observation['imagePaths'] is List)
        ? List<dynamic>.from(observation['imagePaths'] as List)
        : <dynamic>[];
    final xFiles = imagePaths
        .map((p) => p.toString())
        .where((p) => p.trim().isNotEmpty)
        .map((p) => XFile(p))
        .toList(growable: false);

    final existingForEdit = <String, dynamic>{
      'id': id,
      'notes': observation['notes'],
      'images': xFiles,
      'is_unsafe': observation['is_unsafe'] ?? observation['isUnsafe'],
      'unsafe_classification':
          observation['unsafe_classification'] ??
          observation['unsafeClassification'],
    };

    final result = await Navigator.pushNamed(
      context,
      '/add-observation',
      arguments: {
        'title': widget.questionText,
        'existingObservation': existingForEdit,
        'questionReference': widget.questionReference,
        'assetType': widget.assetType,
        'assetId': widget.assetId,
        'assetMakeModel': widget.assetMakeModel,
        'sectionName': widget.sectionName,
      },
    );

    if (!mounted) return;
    if (result is! Map<String, dynamic>) return;

    await _upsertFromEditorResult(result, forceId: id);
  }

  Future<void> _upsertFromEditorResult(
    Map<String, dynamic> result, {
    String? forceId,
  }) async {
    setState(() => _isWorking = true);

    try {
      final notes = (result['notes'] ?? '').toString();
      final isUnsafe = result['is_unsafe'] == true || result['is_unsafe'] == 1;
      final unsafeClassification = result['unsafe_classification']?.toString();

      final images = result['images'];
      final imagePaths = <String>[];
      if (images is List) {
        for (final img in images) {
          if (img is XFile) {
            if (img.path.trim().isNotEmpty) imagePaths.add(img.path);
          } else if (img != null) {
            final p = img.toString();
            if (p.trim().isNotEmpty) imagePaths.add(p);
          }
        }
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final id = (forceId ?? '').trim().isNotEmpty
          ? forceId!.trim()
          : const Uuid().v4();

      final next = <String, dynamic>{
        'id': id,
        'questionReference': widget.questionReference,
        'questionText': widget.questionText,
        'sectionName': widget.sectionName,
        'assetType': widget.assetType,
        'assetMakeModel': widget.assetMakeModel,
        'assetId': widget.assetId,
        'notes': notes,
        'imagePaths': imagePaths,
        'is_unsafe': isUnsafe,
        'unsafe_classification': unsafeClassification,
        'createdAt': now,
        'updatedAt': now,
      };

      final all = _observations
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);

      final index = all.indexWhere((o) => (o['id'] ?? '').toString() == id);
      if (index >= 0) {
        final existingCreatedAt = (all[index]['createdAt'] ?? '').toString();
        if (existingCreatedAt.trim().isNotEmpty) {
          next['createdAt'] = existingCreatedAt;
        }
        all[index] = next;
      } else {
        all.add(next);
      }

      if (mounted) {
        setState(() {
          _observations = all;
        });
      }
      widget.onObservationsChanged(all);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _deleteObservation(Map<String, dynamic> observation) async {
    final id = (observation['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Observation'),
        content: const Text(
          'Are you sure you want to delete this observation? This action cannot be undone.',
        ),
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

    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);
    try {
      final all = _observations
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
      all.removeWhere((o) => (o['id'] ?? '').toString().trim() == id);

      if (mounted) {
        setState(() {
          _observations = all;
        });
      }
      widget.onObservationsChanged(all);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Widget _buildContextBar(BuildContext context) {
    final questionText = widget.questionText.trim();
    if (questionText.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final section = widget.sectionName.trim();
    final assetType = (widget.assetType ?? '').toString().trim();
    final assetId = (widget.assetId ?? '').toString().trim();
    final assetMakeModel = (widget.assetMakeModel ?? '').toString().trim();

    final chips = <String>[];
    if (section.isNotEmpty) chips.add(section);
    if (assetType.isNotEmpty) chips.add(assetType);
    if (assetId.isNotEmpty) chips.add('#$assetId');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (chips.isNotEmpty) const SizedBox(height: 10),
          Text(
            questionText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (assetMakeModel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              assetMakeModel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservationCard(Map<String, dynamic> observation) {
    final notes = (observation['notes'] ?? '').toString();
    final isUnsafe =
        observation['is_unsafe'] == 1 || observation['is_unsafe'] == true;
    final classification = observation['unsafe_classification']?.toString();
    final classificationLabel = switch (classification) {
      'AR' => 'At Risk',
      'ID' => 'Immediately Dangerous',
      _ => classification,
    };
    final isImmediatelyDangerous =
        classification == 'ID' || classification == 'Immediately Dangerous';

    final images = (observation['imagePaths'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((p) => p.trim().isNotEmpty)
        .toList(growable: false);

    final id = (observation['id'] ?? '').toString();

    return Dismissible(
      key: Key('observation_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return (await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Delete'),
                content: const Text(
                  'Are you sure you want to delete this observation?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            )) ??
            false;
      },
      onDismissed: (direction) {
        _deleteObservation(observation);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 32),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: _isWorking ? null : () => _editObservation(observation),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notes.isEmpty ? 'Observation' : notes,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isUnsafe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isImmediatelyDangerous
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          classificationLabel ?? 'Unsafe',
                          style: TextStyle(
                            color: isImmediatelyDangerous
                                ? Colors.red[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final path = images[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppResolvedImage(
                              imagePath: path,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final observations = _filtered;

    return AppScaffold(
      title: 'Observations',
      body: _isWorking
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildContextBar(context),
                Expanded(
                  child: observations.isEmpty
                      ? const Center(child: Text('No observations captured'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: observations.length,
                          itemBuilder: (context, index) {
                            return _buildObservationCard(observations[index]);
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addObservation,
                        icon: const Icon(Icons.add_comment),
                        label: const Text('Add Observation'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
