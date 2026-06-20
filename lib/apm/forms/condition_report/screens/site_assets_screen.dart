import 'package:flutter/material.dart';
import '../../../components/form_widgets.dart';
import '../../../components/entity_card.dart';
import '../../shared/data/form_repository.dart';

class SiteAssetsScreen extends StatefulWidget {
  /// Injected I/O — assets are a generic collection on the form document.
  /// ONE screen, both platforms: add/edit always uses the app's AddAssetScreen
  /// (mobile + web), writing through the repo. No web-only dialog, no mode.
  final FormRepository repo;
  final int? formId;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const SiteAssetsScreen({
    super.key,
    required this.repo,
    required this.formId,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<SiteAssetsScreen> createState() => _SiteAssetsScreenState();
}

class _SiteAssetsScreenState extends State<SiteAssetsScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (mounted) setState(() => _isLoading = true);
    // One source of truth: the form document, via the injected repo. (SQLite on
    // mobile, server payload on web — the screen no longer knows or cares.)
    final assets = await widget.repo.getCollection('assets');
    if (mounted) {
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    }
  }

  void _addAsset() {
    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': widget.formId, 'repo': widget.repo},
    ).then((_) {
      if (mounted) {
        _loadAssets();
      }
    });
  }

  void _editAsset(Map<String, dynamic> asset) {
    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': widget.formId, 'asset': asset, 'repo': widget.repo},
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

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/add-asset',
        arguments: {
          'formId': widget.formId,
          'asset': duplicatedAsset,
          'repo': widget.repo,
        },
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
                                      await widget.repo.deleteCollectionItem(
                                        'assets',
                                        asset['id'] as Object,
                                      );
                                      if (mounted) {
                                        _loadAssets();
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
