import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:uuid/uuid.dart';

class ObservationsListScreen extends StatefulWidget {
  const ObservationsListScreen({super.key});

  @override
  State<ObservationsListScreen> createState() => _ObservationsListScreenState();
}

class _ObservationsListScreenState extends State<ObservationsListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _observations = [];
  bool _isLoading = true;

  List<Map<String, dynamic>>? _observationsJsonArg;
  void Function(List<Map<String, dynamic>> next)? _onObservationsChangedArg;

  bool _useDraftJson = false;
  String? _formType;
  String? _formStatus;
  String? _formUuid;

  int? _formId;
  String? _questionReference;
  String? _questionText;
  String? _sectionName;
  String? _assetId;
  String? _assetType;
  String? _assetMakeModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _formId = args['formId'] as int?;
      _questionReference = args['questionReference'] as String?;
      _questionText = args['questionText'] as String?;
      _sectionName = args['sectionName'] as String?;
      final rawAssetId = args['assetId'];
      _assetId = rawAssetId?.toString();
      _assetType = args['assetType'] as String?;
      _assetMakeModel = args['assetMakeModel'] as String?;

      final obsArg = args['observationsJson'];
      if (obsArg is List) {
        _observationsJsonArg = obsArg
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: true);
      }
      final onObsChanged = args['onObservationsChanged'];
      if (onObsChanged is void Function(List<Map<String, dynamic>>)) {
        _onObservationsChangedArg = onObsChanged;
      }

      if (_questionReference != null &&
          (_formId != null ||
              _observationsJsonArg != null ||
              _onObservationsChangedArg != null)) {
        _initAndLoad();
      }
    }
  }

  Future<void> _initAndLoad() async {
    if (_formId == null) {
      _useDraftJson = true;
      if (!mounted) return;
      await _loadObservations();
      return;
    }

    try {
      final form = await _db.getForm(_formId!);
      if (form != null) {
        _formType = (form['form_type'] ?? '').toString();
        _formStatus = (form['status'] ?? '').toString();
        _formUuid = (form['uuid'] ?? '').toString();

        // JSON-only mode for HNA drafts: observations live in the single forms-row doc.
        _useDraftJson = _formType == 'heat_network_assessment';
      }
    } catch (_) {
      // If this fails, fall back to DB mode.
      _useDraftJson = false;
    }

    if (!mounted) return;
    await _loadObservations();
  }

  Future<void> _loadObservations() async {
    setState(() => _isLoading = true);

    try {
      if (_useDraftJson) {
        // Prefer in-memory list if provided by caller; otherwise read persisted draft.
        final list =
            _observationsJsonArg ??
            await () async {
              if (_formId == null) {
                return <Map<String, dynamic>>[];
              }
              final form = await _db.getForm(_formId!);
              final draftRaw = form?['form_data'];
              final draftDoc = draftRaw is Map
                  ? Map<String, dynamic>.from(draftRaw)
                  : null;

              final obsRaw = draftDoc?['observations'];
              return obsRaw is List
                  ? obsRaw
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList(growable: true)
                  : <Map<String, dynamic>>[];
            }();

        final ref = (_questionReference ?? '').trim();
        _observations = list
            .where((o) {
              final oRef =
                  (o['questionReference'] ?? o['question_reference'] ?? '')
                      .toString()
                      .trim();
              return oRef == ref;
            })
            .toList(growable: false);
      } else {
        final observations = await _db.getQuestionObservations(
          _formId!,
          _questionReference!,
        );
        _observations = observations;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading observations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addObservation() async {
    final result = await Navigator.pushNamed(
      context,
      '/add-observation',
      arguments: {
        'title': _questionText,
        'existingObservation': null,
        'questionReference': _questionReference,
        'assetType': _assetType,
        'sectionName': _sectionName,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      await _saveObservation(result);
      await _loadObservations();
    }
  }

  Future<void> _editObservation(Map<String, dynamic> observation) async {
    // Convert image paths (Strings) to XFile objects for editing
    final imagesRaw =
        (observation['images'] ?? observation['imagePaths']) as List<dynamic>?;
    final xFileImages = imagesRaw
        ?.map((path) => XFile(path.toString()))
        .toList(growable: false);

    final observationForEdit = {
      'id': observation['id'], // Pass the ID so we know we're editing
      'notes': observation['notes'],
      'images': xFileImages,
      'is_unsafe': observation['is_unsafe'],
      'unsafe_classification': observation['unsafe_classification'],
    };

    final result = await Navigator.pushNamed(
      context,
      '/add-observation',
      arguments: {
        'title': _questionText,
        'existingObservation': observationForEdit,
        'questionReference': _questionReference,
        'assetType': _assetType,
        'sectionName': _sectionName,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      await _saveObservation(result, observationId: observation['id']);
      await _loadObservations();
    }
  }

  Future<void> _saveObservation(
    Map<String, dynamic> observationData, {
    dynamic observationId,
  }) async {
    try {
      final images = observationData['images'] as List<XFile>?;
      final imagePaths = images?.map((img) => img.path).toList();
      final isUnsafe = observationData['is_unsafe'] as bool? ?? false;
      final unsafeClassification =
          observationData['unsafe_classification'] as String?;

      if (_useDraftJson) {
        if (_formId == null) {
          final all = (_observationsJsonArg ?? <Map<String, dynamic>>[])
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true);

          final existingId = (observationId ?? '').toString().trim();
          final id = existingId.isEmpty ? const Uuid().v4() : existingId;
          final nowUtc = DateTime.now().toUtc().toIso8601String();

          final record = <String, dynamic>{
            'id': id,
            'questionReference': _questionReference,
            'notes': observationData['notes'] as String?,
            'imagePaths': imagePaths ?? <String>[],
            'questionText': _questionText,
            'sectionName': _sectionName,
            'assetId': _assetId,
            'assetType': _assetType,
            'assetMakeModel': _assetMakeModel,
            'is_unsafe': isUnsafe,
            'unsafe_classification': unsafeClassification,
            'createdAt': nowUtc,
            'updatedAt': nowUtc,
          };

          final idx = all.indexWhere((o) => (o['id'] ?? '').toString() == id);
          if (idx >= 0) {
            final existing = all[idx];
            record['createdAt'] =
                (existing['createdAt'] ?? existing['createdAtUtc'] ?? nowUtc)
                    .toString();
            all[idx] = record;
          } else {
            all.add(record);
          }

          _observationsJsonArg = all;
          _onObservationsChangedArg?.call(all);
          return;
        }

        final form = await _db.getForm(_formId!);
        if (form == null) return;
        final draftRaw = form['form_data'];
        if (draftRaw is! Map) return;
        final draftDoc = Map<String, dynamic>.from(draftRaw);

        final obsRaw = draftDoc['observations'];
        final all = obsRaw is List
            ? obsRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(growable: true)
            : <Map<String, dynamic>>[];

        final existingId = (observationId ?? '').toString().trim();
        final id = existingId.isEmpty ? const Uuid().v4() : existingId;
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        final record = <String, dynamic>{
          'id': id,
          'questionReference': _questionReference,
          'notes': observationData['notes'] as String?,
          // Canonical key for HNA draft JSON and submission attachments.
          'imagePaths': imagePaths ?? <String>[],
          'questionText': _questionText,
          'sectionName': _sectionName,
          'assetId': _assetId,
          'assetType': _assetType,
          'assetMakeModel': _assetMakeModel,
          'is_unsafe': isUnsafe,
          'unsafe_classification': unsafeClassification,
          'createdAt': nowUtc,
          'updatedAt': nowUtc,
        };

        final idx = all.indexWhere((o) => (o['id'] ?? '').toString() == id);
        if (idx >= 0) {
          final existing = all[idx];
          record['createdAt'] =
              (existing['createdAt'] ?? existing['createdAtUtc'] ?? nowUtc)
                  .toString();
          all[idx] = record;
        } else {
          all.add(record);
        }

        draftDoc['observations'] = all;

        // Keep caller in sync so parent autosaves/submissions don't overwrite.
        final cb = _onObservationsChangedArg;
        if (cb != null) {
          _observationsJsonArg = all;
          cb(all);
        }

        final status = (form['status'] ?? _formStatus ?? 'draft').toString();
        final formType =
            (form['form_type'] ?? _formType ?? 'heat_network_assessment')
                .toString();
        final uuid = (form['uuid'] ?? _formUuid ?? '').toString();

        await _db.saveForm(
          id: _formId,
          formType: formType,
          status: status,
          formData: jsonDecode(jsonEncode(draftDoc)) as Map<String, dynamic>,
          uuid: uuid.isEmpty ? null : uuid,
        );
      } else {
        await _db.saveObservation(
          id: observationId is int ? observationId : null,
          formId: _formId!,
          questionReference: _questionReference!,
          notes: observationData['notes'] as String?,
          imagePaths: imagePaths,
          questionText: _questionText,
          sectionName: _sectionName,
          assetId: int.tryParse((_assetId ?? '').toString()),
          assetType: _assetType,
          assetMakeModel: _assetMakeModel,
          isUnsafe: isUnsafe,
          unsafeClassification: unsafeClassification,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving observation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteObservation(Map<String, dynamic> observation) async {
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

    if (confirmed == true) {
      try {
        if (_useDraftJson) {
          if (_formId == null) {
            final all = (_observationsJsonArg ?? <Map<String, dynamic>>[])
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: true);

            final id = (observation['id'] ?? '').toString();
            all.removeWhere((o) => (o['id'] ?? '').toString() == id);

            _observationsJsonArg = all;
            _onObservationsChangedArg?.call(all);
            await _loadObservations();
            return;
          }

          final form = await _db.getForm(_formId!);
          if (form == null) return;
          final draftRaw = form['form_data'];
          if (draftRaw is! Map) return;
          final draftDoc = Map<String, dynamic>.from(draftRaw);

          final obsRaw = draftDoc['observations'];
          final all = obsRaw is List
              ? obsRaw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(growable: true)
              : <Map<String, dynamic>>[];

          final id = (observation['id'] ?? '').toString();
          all.removeWhere((o) => (o['id'] ?? '').toString() == id);
          draftDoc['observations'] = all;

          final cb = _onObservationsChangedArg;
          if (cb != null) {
            _observationsJsonArg = all;
            cb(all);
          }

          final status = (form['status'] ?? _formStatus ?? 'draft').toString();
          final formType =
              (form['form_type'] ?? _formType ?? 'heat_network_assessment')
                  .toString();
          final uuid = (form['uuid'] ?? _formUuid ?? '').toString();

          await _db.saveForm(
            id: _formId,
            formType: formType,
            status: status,
            formData: jsonDecode(jsonEncode(draftDoc)) as Map<String, dynamic>,
            uuid: uuid.isEmpty ? null : uuid,
          );
          await _loadObservations();
        } else {
          final id = observation['id'];
          if (id is int) {
            await _db.deleteObservation(id);
            await _loadObservations();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting observation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildObservationCard(Map<String, dynamic> observation) {
    final notes = observation['notes'] as String? ?? '';
    final isUnsafe =
        observation['is_unsafe'] == 1 || observation['is_unsafe'] == true;
    final classification = observation['unsafe_classification'] as String?;
    final classificationLabel = switch (classification) {
      'AR' => 'At Risk',
      'ID' => 'Immediately Dangerous',
      _ => classification,
    };
    final isImmediatelyDangerous =
        classification == 'ID' || classification == 'Immediately Dangerous';
    final images =
        ((observation['images'] ?? observation['imagePaths'])
                    as List<dynamic>? ??
                [])
            .map((e) => e.toString())
            .where((p) => p.isNotEmpty)
            .toList();

    return Dismissible(
      key: Key('observation_${observation['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
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
                );
              },
            ) ??
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
          onTap: () => _editObservation(observation),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isUnsafe
                  ? const Border(left: BorderSide(color: Colors.red, width: 4))
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Observation',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (isUnsafe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.red[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'UNSAFE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[900],
                                      ),
                                    ),
                                  ),
                                ],
                                if (classificationLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isImmediatelyDangerous
                                          ? Colors.red[100]
                                          : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      classificationLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isImmediatelyDangerous
                                            ? Colors.red[900]
                                            : Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                notes,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (images.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 72,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  itemBuilder: (context, imageIndex) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(images[imageIndex]),
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 72,
                                            height: 72,
                                            color: Colors.grey[100],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Observations',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_questionText != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey[50]!, Colors.grey[100]!],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                        left: BorderSide(
                          color: _assetId != null
                              ? Colors.blue[300]!
                              : Colors.orange[300]!,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_sectionName != null) ...[
                                Text(
                                  _sectionName!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _assetId != null
                                          ? Colors.blue[100]
                                          : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _assetId != null ? 'ASSET' : 'QUESTION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _assetId != null
                                            ? Colors.blue[900]
                                            : Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _questionText!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ],
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
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _addObservation,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Observation'),
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
                ),
                Expanded(
                  child: _observations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notes_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No observations yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _observations.length,
                          itemBuilder: (context, index) {
                            return _buildObservationCard(_observations[index]);
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
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Return'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
