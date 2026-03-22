import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../components/form_widgets.dart';
import '../../../components/entity_card.dart';
import '../../shared/editor/form_editor_contract.dart';

class PlantRoomsListScreen extends StatefulWidget {
  final int? formId;
  final Map<String, dynamic> formData;
  final FormEditorRuntimeMode mode;
  final void Function(String key, dynamic value)? onDataChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const PlantRoomsListScreen({
    super.key,
    required this.formId,
    required this.formData,
    this.mode = FormEditorRuntimeMode.mobileDraft,
    this.onDataChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<PlantRoomsListScreen> createState() => _PlantRoomsListScreenState();
}

class _PlantRoomsListScreenState extends State<PlantRoomsListScreen> {
  List<Map<String, dynamic>> _plantRooms = [];
  bool _isLoading = true;

  bool get _isWebEditorMode => widget.mode == FormEditorRuntimeMode.webEditor;

  @override
  void initState() {
    super.initState();
    _loadPlantRooms();
  }

  Future<void> _loadPlantRooms() async {
    if (_isWebEditorMode) {
      final raw = widget.formData['plantRooms'];
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _plantRooms = list;
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.formId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }
    final plantRooms = await DatabaseHelper.instance.getPlantRooms(
      widget.formId!,
    );
    if (mounted) {
      setState(() {
        _plantRooms = List<Map<String, dynamic>>.from(plantRooms);
        _isLoading = false;
      });
    }
  }

  void _addPlantRoom() {
    if (_isWebEditorMode) {
      _openPlantRoomEditor();
      return;
    }

    Navigator.pushNamed(
      context,
      '/add-plant-room',
      arguments: {'formId': widget.formId, 'formData': widget.formData},
    ).then((_) {
      if (mounted) {
        _loadPlantRooms();
      }
    });
  }

  void _editPlantRoom(Map<String, dynamic> plantRoom) {
    if (_isWebEditorMode) {
      _openPlantRoomEditor(existing: plantRoom);
      return;
    }

    Navigator.pushNamed(
      context,
      '/add-plant-room',
      arguments: {
        'formId': widget.formId,
        'formData': widget.formData,
        'plantRoom': plantRoom,
      },
    ).then((_) {
      if (mounted) {
        _loadPlantRooms();
      }
    });
  }

  Future<bool> _confirmAndDeletePlantRoom(
    Map<String, dynamic> plantRoom,
  ) async {
    final location = plantRoom['location'] as String? ?? 'No Location';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plant Room'),
        content: Text(
          'Are you sure you want to delete this plant room?\n\nLocation: $location',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return false;
    }

    if (_isWebEditorMode) {
      final next = _plantRooms
          .where((row) => row['id'] != plantRoom['id'])
          .toList(growable: false);
      _persistPlantRooms(next);
      return true;
    }

    await DatabaseHelper.instance.deletePlantRoom(plantRoom['id'] as int);
    return true;
  }

  int _nextPlantRoomId() {
    var maxId = 0;
    for (final row in _plantRooms) {
      final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  void _persistPlantRooms(List<Map<String, dynamic>> rooms) {
    final next = rooms
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    setState(() {
      _plantRooms = next;
      widget.formData['plantRooms'] = next;
    });
    widget.onDataChanged?.call('plantRooms', next);
  }

  Future<void> _openPlantRoomEditor({Map<String, dynamic>? existing}) async {
    final locationController = TextEditingController(
      text: (existing?['location'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Plant Room' : 'Edit Plant Room'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(labelText: 'Location'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final location = locationController.text.trim();
    if (location.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final next = _plantRooms
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);

    if (existing == null) {
      next.add({
        'id': _nextPlantRoomId(),
        'location': location,
        'accessImages': const <String>[],
        'internalImages': const <String>[],
        'created_at': now,
        'updated_at': now,
      });
    } else {
      final idx = next.indexWhere((row) => row['id'] == existing['id']);
      if (idx >= 0) {
        next[idx] = {...next[idx], 'location': location, 'updated_at': now};
      }
    }

    _persistPlantRooms(next);
  }

  @override
  Widget build(BuildContext context) {
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
                            'Plant Rooms',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Add Plant Room',
                            icon: Icons.add,
                            onPressed: _addPlantRoom,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _plantRooms.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.factory_outlined,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Plant Rooms',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _plantRooms.length,
                              itemBuilder: (context, index) {
                                final plantRoom = _plantRooms[index];
                                final location =
                                    plantRoom['location'] as String? ??
                                    'No Location';
                                final accessImageCount =
                                    (plantRoom['accessImages'] as List?)
                                        ?.length ??
                                    0;
                                final internalImageCount =
                                    (plantRoom['internalImages'] as List?)
                                        ?.length ??
                                    0;

                                return Dismissible(
                                  key: ValueKey<String>(
                                    (plantRoom['id'] ?? 'no-id').toString(),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    final deleted =
                                        await _confirmAndDeletePlantRoom(
                                          plantRoom,
                                        );
                                    return deleted;
                                  },
                                  onDismissed: (direction) {
                                    if (!mounted) return;
                                    setState(() {
                                      _plantRooms = _plantRooms
                                          .where(
                                            (row) =>
                                                row['id'] != plantRoom['id'],
                                          )
                                          .toList();
                                    });
                                  },
                                  child: AppEntityCard(
                                    title: location,
                                    details: [
                                      AppEntityDetail(
                                        icon: Icons.image,
                                        label:
                                            'Access Images: $accessImageCount',
                                      ),
                                      AppEntityDetail(
                                        icon: Icons.photo_library,
                                        label:
                                            'Internal Images: $internalImageCount',
                                      ),
                                    ],
                                    onTap: () => _editPlantRoom(plantRoom),
                                    onDelete: () async {
                                      final deleted =
                                          await _confirmAndDeletePlantRoom(
                                            plantRoom,
                                          );
                                      if (deleted && mounted) {
                                        _loadPlantRooms();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),

        // Navigation Buttons
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
            child: Row(
              children: [
                Expanded(
                  child: AppButton(text: 'Back', onPressed: widget.onBack),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(text: 'Next', onPressed: widget.onNext),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
