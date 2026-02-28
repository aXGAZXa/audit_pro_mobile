import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../models/heat_generator.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/entity_card.dart';
import 'add_heat_generator_screen.dart';

class HeatGeneratorListScreen extends StatefulWidget {
  const HeatGeneratorListScreen({super.key});

  @override
  State<HeatGeneratorListScreen> createState() =>
      _HeatGeneratorListScreenState();
}

class _HeatGeneratorListScreenState extends State<HeatGeneratorListScreen> {
  List<HeatGenerator> _items = [];
  int? _formId;
  bool _isLoading = true;
  bool _readOnly = false;
  final String _title = 'Heat Generators';
  final String _addButtonLabel = 'Add Heat Generator';
  final String _emptyStateLabel = 'No Heat Generators';

  Future<bool> _confirmDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Generator'),
        content: const Text(
          'Are you sure you want to delete this Heat Generator?',
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
    return confirm == true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _formId = args['formId'] as int?;
        _readOnly = args['readOnly'] as bool? ?? false;
        _loadItems();
      }
    }
  }

  Future<void> _loadItems() async {
    if (_formId == null) return;

    setState(() => _isLoading = true);
    final items = await DatabaseHelper.instance.getHeatGenerators(_formId!);

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatGeneratorScreen(),
        settings: RouteSettings(arguments: {'formId': _formId}),
      ),
    ).then((_) => _loadItems());
  }

  void _editItem(HeatGenerator item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatGeneratorScreen(),
        settings: RouteSettings(
          arguments: {'formId': _formId, 'generator': item},
        ),
      ),
    ).then((_) => _loadItems());
  }

  Future<void> _duplicateItem(HeatGenerator item) async {
    final newItem = HeatGenerator(
      formId: item.formId,
      generatorType: item.generatorType,
      fuelType: item.fuelType,
      location: item.location,
      make: item.make,
      model: item.model,
      serialNumber: null,
      capacity: item.capacity,
      ageRange: item.ageRange,
      condition: '', // Empty string will be converted to null in add screen
      operational: null,
      hasIndividualMeter: null,
      imagePaths: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatGeneratorScreen(),
        settings: RouteSettings(
          arguments: {'formId': _formId, 'generator': newItem},
        ),
      ),
    ).then((_) => _loadItems());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                      left: BorderSide(color: Colors.blue[300]!, width: 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEAT NETWORK ASSESSMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _title,
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
                if (!_readOnly)
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
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: Text(_addButtonLabel),
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
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fireplace,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _emptyStateLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final title = '${item.make} ${item.model}';
                            final subtitle =
                                '${item.generatorType} - ${item.fuelType}';

                            final card = AppEntityCard(
                              title: title.trim().isEmpty
                                  ? 'Unknown Generator'
                                  : title,
                              subtitle: subtitle,
                              imagePaths: item.imagePaths,
                              details: [
                                if (item.serialNumber != null &&
                                    item.serialNumber!.isNotEmpty)
                                  Text(
                                    'S/N: ${item.serialNumber}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                if (item.location.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.location,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                              actions: _readOnly
                                  ? null
                                  : [
                                      IconButton(
                                        icon: const Icon(Icons.content_copy),
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        tooltip: 'Duplicate',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Duplicate Generator',
                                              ),
                                              content: const Text(
                                                'Do you want to duplicate this generator?\n\nType, Make, Model, Capacity, and Location will be copied.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('No'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Yes'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            _duplicateItem(item);
                                          }
                                        },
                                      ),
                                    ],
                              onTap: _readOnly ? null : () => _editItem(item),
                            );

                            if (_readOnly) return card;

                            return Dismissible(
                              key: Key('heat_generator_${item.id ?? index}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) =>
                                  _confirmDeleteDialog(),
                              onDismissed: (direction) async {
                                if (item.id != null) {
                                  await DatabaseHelper.instance
                                      .deleteHeatGenerator(item.id!);
                                  _loadItems();
                                }
                              },
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              child: card,
                            );
                          },
                        ),
                ),
                Container(
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                ),
              ],
            ),
    );
  }
}
