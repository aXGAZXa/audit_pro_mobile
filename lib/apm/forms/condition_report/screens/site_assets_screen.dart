import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../components/form_widgets.dart';
import '../../../components/entity_card.dart';
import '../../shared/editor/form_editor_contract.dart';

class SiteAssetsScreen extends StatefulWidget {
  final int? formId;
  final Map<String, dynamic> formData;
  final FormEditorRuntimeMode mode;
  final void Function(String key, dynamic value)? onDataChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const SiteAssetsScreen({
    super.key,
    required this.formId,
    required this.formData,
    this.mode = FormEditorRuntimeMode.mobileDraft,
    this.onDataChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<SiteAssetsScreen> createState() => _SiteAssetsScreenState();
}

class _SiteAssetsScreenState extends State<SiteAssetsScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _isLoading = true;

  bool get _isWebEditorMode => widget.mode == FormEditorRuntimeMode.webEditor;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (_isWebEditorMode) {
      final raw = widget.formData['assets'];
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _assets = list;
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
    final assets = await DatabaseHelper.instance.getAssets(widget.formId!);
    if (mounted) {
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    }
  }

  void _addAsset() {
    if (_isWebEditorMode) {
      _openAssetEditor();
      return;
    }

    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': widget.formId},
    ).then((_) {
      if (mounted) {
        _loadAssets();
      }
    });
  }

  void _editAsset(Map<String, dynamic> asset) {
    if (_isWebEditorMode) {
      _openAssetEditor(existing: asset);
      return;
    }

    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': widget.formId, 'asset': asset},
    ).then((_) {
      if (mounted) {
        _loadAssets();
      }
    });
  }

  Future<void> _duplicateAsset(Map<String, dynamic> asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Asset'),
        content: const Text(
          'Do you want to duplicate this asset?\n\nOnly Type, Make, Model, Location, and Age will be copied.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Create a new asset with only selected fields
      final duplicatedAsset = <String, dynamic>{
        'asset_type_id': asset['asset_type_id'],
        'asset_make': asset['asset_make'],
        'asset_model': asset['asset_model'],
        'location': asset['location'],
        'estimate_age': asset['estimate_age'],
        'asset_type_details': asset['asset_type_details'],
      };

      if (_isWebEditorMode) {
        final next = _assets
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: true);
        duplicatedAsset['id'] = _nextAssetId();
        next.add(duplicatedAsset);
        _persistAssets(next);
        return;
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/add-asset',
        arguments: {'formId': widget.formId, 'asset': duplicatedAsset},
      ).then((_) {
        if (mounted) {
          _loadAssets();
        }
      });
    }
  }

  void _saveAndContinue() {
    if (_assets.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text(
            'Please add at least one asset before continuing',
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

  int _nextAssetId() {
    var maxId = 0;
    for (final row in _assets) {
      final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  void _persistAssets(List<Map<String, dynamic>> assets) {
    final next = assets
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    setState(() {
      _assets = next;
      widget.formData['assets'] = next;
    });
    widget.onDataChanged?.call('assets', next);
  }

  Future<void> _openAssetEditor({Map<String, dynamic>? existing}) async {
    final typeController = TextEditingController(
      text: ((existing?['asset_type_details'] as Map?)?['asset_type'] ?? '')
          .toString(),
    );
    final makeController = TextEditingController(
      text: (existing?['asset_make'] ?? '').toString(),
    );
    final modelController = TextEditingController(
      text: (existing?['asset_model'] ?? '').toString(),
    );
    final locationController = TextEditingController(
      text: (existing?['location'] ?? '').toString(),
    );
    final ageController = TextEditingController(
      text: (existing?['estimate_age'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Asset' : 'Edit Asset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Asset Type'),
              ),
              TextField(
                controller: makeController,
                decoration: const InputDecoration(labelText: 'Make'),
              ),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Estimated Age'),
              ),
            ],
          ),
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

    final type = typeController.text.trim();
    if (type.isEmpty) return;

    final next = _assets
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);

    final asset = <String, dynamic>{
      ...(existing ?? const <String, dynamic>{}),
      'id': existing?['id'] ?? _nextAssetId(),
      'asset_make': makeController.text.trim(),
      'asset_model': modelController.text.trim(),
      'location': locationController.text.trim(),
      'estimate_age': ageController.text.trim(),
      'asset_type_details': {
        ...((existing?['asset_type_details'] is Map)
            ? Map<String, dynamic>.from(existing!['asset_type_details'] as Map)
            : <String, dynamic>{}),
        'asset_type': type,
      },
    };

    final idx = next.indexWhere((row) => row['id'] == asset['id']);
    if (idx >= 0) {
      next[idx] = asset;
    } else {
      next.add(asset);
    }

    _persistAssets(next);
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
                            'Site Assets',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Add Asset',
                            icon: Icons.add,
                            onPressed: _addAsset,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _assets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Assets',
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
                              itemCount: _assets.length,
                              itemBuilder: (context, index) {
                                final asset = _assets[index];
                                final assetTypeDetails =
                                    asset['asset_type_details']
                                        as Map<String, dynamic>?;
                                final assetTypeName =
                                    assetTypeDetails?['asset_type']
                                        as String? ??
                                    'Unknown';

                                return AppEntityCard(
                                  title: assetTypeName,
                                  subtitle:
                                      '${asset['asset_make'] ?? ''} ${asset['asset_model'] ?? ''}'
                                          .trim(),
                                  details: [
                                    if (asset['location'] != null)
                                      AppEntityDetail(
                                        icon: Icons.location_on,
                                        label: asset['location'] as String,
                                      ),
                                  ],
                                  onTap: () => _editAsset(asset),
                                  actions: [
                                    AppEntityAction(
                                      icon: Icons.content_copy,
                                      label: 'Duplicate',
                                      onPressed: () => _duplicateAsset(asset),
                                    ),
                                  ],
                                  onDelete: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Asset'),
                                        content: Text(
                                          'Are you sure you want to delete this $assetTypeName?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              foregroundColor: Theme.of(
                                                context,
                                              ).colorScheme.onError,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      if (_isWebEditorMode) {
                                        final next = _assets
                                            .where(
                                              (row) => row['id'] != asset['id'],
                                            )
                                            .toList(growable: false);
                                        _persistAssets(next);
                                      } else {
                                        await DatabaseHelper.instance
                                            .deleteAsset(
                                              asset['id'] as int,
                                              formId: widget.formId,
                                            );
                                        if (mounted) {
                                          _loadAssets();
                                        }
                                      }
                                    }
                                  },
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
            child: Row(
              children: [
                Expanded(
                  child: AppButton(text: 'Back', onPressed: widget.onBack),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(text: 'Next', onPressed: _saveAndContinue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
