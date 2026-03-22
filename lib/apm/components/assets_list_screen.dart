import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../components/app_scaffold.dart';

class AssetsListScreen extends StatefulWidget {
  const AssetsListScreen({super.key});

  @override
  State<AssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends State<AssetsListScreen> {
  List<Map<String, dynamic>> _assets = [];
  int? _formId;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _formId = args['formId'] as int?;
        _loadAssets();
      }
    }
  }

  Future<void> _loadAssets() async {
    if (_formId == null) return;

    setState(() => _isLoading = true);
    final assets = await DatabaseHelper.instance.getAssets(_formId!);
    setState(() {
      _assets = assets;
      _isLoading = false;
    });
  }

  void _addAsset() {
    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': _formId},
    ).then((_) => _loadAssets());
  }

  void _editAsset(Map<String, dynamic> asset) {
    Navigator.pushNamed(
      context,
      '/add-asset',
      arguments: {'formId': _formId, 'asset': asset},
    ).then((_) => _loadAssets());
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
        arguments: {'formId': _formId, 'asset': duplicatedAsset},
      ).then((_) => _loadAssets());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Assets',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _addAsset,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Asset'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _assets.length,
                          itemBuilder: (context, index) {
                            final asset = _assets[index];
                            final assetTypeDetails =
                                asset['asset_type_details']
                                    as Map<String, dynamic>?;
                            final assetTypeName =
                                assetTypeDetails?['asset_type'] as String? ??
                                'Unknown';
                            final images = asset['images'] as List<dynamic>?;

                            return Dismissible(
                              key: Key('asset_${asset['id']}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
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
                              },
                              onDismissed: (direction) async {
                                await DatabaseHelper.instance.deleteAsset(
                                  asset['id'] as int,
                                  formId: _formId,
                                );
                                _loadAssets();
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _editAsset(asset),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    assetTypeName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (asset['asset_make'] !=
                                                          null ||
                                                      asset['asset_model'] !=
                                                          null)
                                                    Text(
                                                      '${asset['asset_make'] ?? ''} ${asset['asset_model'] ?? ''}'
                                                          .trim(),
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.content_copy,
                                              ),
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              onPressed: () =>
                                                  _duplicateAsset(asset),
                                            ),
                                          ],
                                        ),
                                        if (asset['location'] != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.outline,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(asset['location'] as String),
                                            ],
                                          ),
                                        ],
                                        if (asset['operational'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                asset['operational'] == 'YES'
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                size: 16,
                                                color:
                                                    asset['operational'] ==
                                                        'YES'
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Operational: ${asset['operational']}',
                                                style: TextStyle(
                                                  color:
                                                      asset['operational'] ==
                                                          'YES'
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (images != null &&
                                            images.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 80,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: images.length,
                                              itemBuilder: (context, imgIndex) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Image.file(
                                                      File(
                                                        images[imgIndex]
                                                            .toString(),
                                                      ),
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              width: 80,
                                                              height: 80,
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainerHighest,
                                                              child: const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                              ),
                                                            );
                                                          },
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
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                    ),
                    child: const Text('Return'),
                  ),
                ),
              ],
            ),
    );
  }
}
