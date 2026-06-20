import 'package:flutter/material.dart';
import '../../../components/form_widgets.dart';
import '../../../components/entity_card.dart';
import '../../shared/data/form_repository.dart';

class PlantRoomsListScreen extends StatefulWidget {
  /// Injected I/O — plant rooms are a generic collection on the form document.
  /// ONE screen, both platforms: add/edit always uses the app's
  /// AddPlantRoomScreen, writing through the repo. No web-only dialog, no mode.
  final FormRepository repo;
  final int? formId;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const PlantRoomsListScreen({
    super.key,
    required this.repo,
    required this.formId,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<PlantRoomsListScreen> createState() => _PlantRoomsListScreenState();
}

class _PlantRoomsListScreenState extends State<PlantRoomsListScreen> {
  List<Map<String, dynamic>> _plantRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlantRooms();
  }

  Future<void> _loadPlantRooms() async {
    if (mounted) setState(() => _isLoading = true);
    // Single source of truth: the form document, via the injected repo.
    final plantRooms = await widget.repo.getCollection('plantRooms');
    if (mounted) {
      setState(() {
        _plantRooms = plantRooms;
        _isLoading = false;
      });
    }
  }

  void _addPlantRoom() {
    Navigator.pushNamed(
      context,
      '/add-plant-room',
      arguments: {'formId': widget.formId, 'repo': widget.repo},
    ).then((_) {
      if (mounted) {
        _loadPlantRooms();
      }
    });
  }

  void _editPlantRoom(Map<String, dynamic> plantRoom) {
    Navigator.pushNamed(
      context,
      '/add-plant-room',
      arguments: {
        'formId': widget.formId,
        'plantRoom': plantRoom,
        'repo': widget.repo,
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

    await widget.repo.deleteCollectionItem('plantRooms', plantRoom['id'] as Object);
    return true;
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
