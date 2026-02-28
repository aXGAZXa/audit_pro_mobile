import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';

class ObservationsListScreen extends StatefulWidget {
  const ObservationsListScreen({super.key});

  @override
  State<ObservationsListScreen> createState() => _ObservationsListScreenState();
}

class _ObservationsListScreenState extends State<ObservationsListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _observations = [];
  bool _isLoading = true;

  int? _formId;
  String? _questionReference;
  String? _questionText;
  String? _sectionName;
  int? _assetId;
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
      _assetId = args['assetId'] as int?;
      _assetType = args['assetType'] as String?;
      _assetMakeModel = args['assetMakeModel'] as String?;

      if (_formId != null && _questionReference != null) {
        _loadObservations();
      }
    }
  }

  Future<void> _loadObservations() async {
    setState(() => _isLoading = true);

    try {
      final observations = await _db.getQuestionObservations(
        _formId!,
        _questionReference!,
      );

      _observations = observations;
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
      // Save the new observation to database
      await _saveObservation(result);
      await _loadObservations();
    }
  }

  Future<void> _editObservation(Map<String, dynamic> observation) async {
    // Convert image paths (Strings) to XFile objects for editing
    final images = observation['images'] as List<dynamic>?;
    final xFileImages = images?.map((path) => XFile(path.toString())).toList();

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
      // Update the observation in database - pass the ID
      await _saveObservation(result, observationId: observation['id'] as int);
      await _loadObservations();
    }
  }

  Future<void> _saveObservation(
    Map<String, dynamic> observationData, {
    int? observationId,
  }) async {
    try {
      final images = observationData['images'] as List<XFile>?;
      final imagePaths = images?.map((img) => img.path).toList();
      final isUnsafe = observationData['is_unsafe'] as bool? ?? false;
      final unsafeClassification =
          observationData['unsafe_classification'] as String?;

      await _db.saveObservation(
        id: observationId, // Pass the ID if editing
        formId: _formId!,
        questionReference: _questionReference!,
        notes: observationData['notes'] as String?,
        imagePaths: imagePaths,
        questionText: _questionText,
        sectionName: _sectionName,
        assetId: _assetId,
        assetType: _assetType,
        assetMakeModel: _assetMakeModel,
        isUnsafe: isUnsafe,
        unsafeClassification: unsafeClassification,
      );
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
        await _db.deleteObservation(observation['id'] as int);
        await _loadObservations();
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
    final images = (observation['images'] as List<dynamic>? ?? [])
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
