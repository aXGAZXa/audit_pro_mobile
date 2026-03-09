import 'package:flutter/material.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/entity_card.dart';
import 'add_communal_control_screen.dart';

class CommunalControlListScreen extends StatefulWidget {
  const CommunalControlListScreen({super.key});

  @override
  State<CommunalControlListScreen> createState() =>
      _CommunalControlListScreenState();
}

class _CommunalControlListScreenState extends State<CommunalControlListScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;
  List<Map<String, dynamic>>? _observationsJson;
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;
  bool _isLoading = true;
  bool _readOnly = false;
  final String _title = 'Communal Controls';
  final String _addButtonLabel = 'Add Communal Control';
  final String _emptyStateLabel = 'No Communal Controls';

  Future<bool> _confirmDeleteDialog(String title, String message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    if (_assetsJson != null) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final assets = args['assetsJson'];
    final onAssetsChanged = args['onAssetsChanged'];
    _assetsJson = assets is Map ? Map<String, dynamic>.from(assets) : null;
    _onAssetsChanged = onAssetsChanged is Function
        ? (onAssetsChanged as void Function(Map<String, dynamic>))
        : null;

    final obs = args['observationsJson'];
    _observationsJson = obs is List
        ? obs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : null;

    final onObsChanged = args['onObservationsChanged'];
    final upstreamOnObsChanged = onObsChanged is Function
        ? (onObsChanged as void Function(List<Map<String, dynamic>>))
        : null;
    _onObservationsChanged = upstreamOnObsChanged == null
        ? null
        : (next) {
            _observationsJson = next;
            upstreamOnObsChanged(next);
          };

    _readOnly = args['readOnly'] as bool? ?? false;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    final assets = _assetsJson;
    if (assets == null) return;

    final raw = assets['communalControls'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : <Map<String, dynamic>>[];

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _emitItems(List<Map<String, dynamic>> nextItems) {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    if (assets == null || onAssetsChanged == null) return;

    final nextAssets = Map<String, dynamic>.from(assets);
    nextAssets['communalControls'] = nextItems;
    _assetsJson = nextAssets;
    onAssetsChanged(nextAssets);
  }

  Future<void> _addItem() async {
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCommunalControlScreen(),
        settings: RouteSettings(
          arguments: {
            'control': null,
            'assetsJson': _assetsJson,
            'onAssetsChanged': _onAssetsChanged,
            'observationsJson': _observationsJson,
            'onObservationsChanged': _onObservationsChanged,
          },
        ),
      ),
    );

    if (saved == null) return;
    _upsertAndRefresh(saved);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCommunalControlScreen(),
        settings: RouteSettings(
          arguments: {
            'control': item,
            'assetsJson': _assetsJson,
            'onAssetsChanged': _onAssetsChanged,
            'observationsJson': _observationsJson,
            'onObservationsChanged': _onObservationsChanged,
          },
        ),
      ),
    );

    if (saved == null) return;
    _upsertAndRefresh(saved);
  }

  void _upsertAndRefresh(Map<String, dynamic> saved) {
    final id = (saved['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final nextItems = _items
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: true);

    final index = nextItems.indexWhere((x) => (x['id'] ?? '').toString() == id);
    if (index >= 0) {
      nextItems[index] = saved;
    } else {
      nextItems.add(saved);
    }

    _emitItems(nextItems);
    setState(() => _items = nextItems);
  }

  Future<void> _duplicateItem(Map<String, dynamic> item) async {
    final newItem = <String, dynamic>{
      'controlType': item['controlType'],
      'location': item['location'],
      'make': item['make'],
      'model': item['model'],
      'serialNumber': null,
      'condition': null,
      'operational': null,
      'imagePaths': const <String>[],
    };

    await _editItem(newItem);
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
                                Icons.settings_remote,
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

                            final title = (item['controlType'] ?? '')
                                .toString()
                                .trim();
                            final make = (item['make'] ?? '').toString().trim();
                            final model = (item['model'] ?? '')
                                .toString()
                                .trim();
                            final subtitle = '$make $model'.trim();
                            final location = (item['location'] ?? '')
                                .toString()
                                .trim();
                            final imagePathsRaw = item['imagePaths'];
                            final imagePaths = imagePathsRaw is List
                                ? imagePathsRaw
                                      .map((e) => e.toString())
                                      .where((e) => e.trim().isNotEmpty)
                                      .toList(growable: false)
                                : <String>[];

                            final card = AppEntityCard(
                              title: title,
                              subtitle: subtitle,
                              imagePaths: imagePaths,
                              onTap: _readOnly ? null : () => _editItem(item),
                              actions: [
                                if (!_readOnly)
                                  AppEntityAction(
                                    icon: Icons.content_copy,
                                    label: 'Duplicate',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            'Duplicate Control',
                                          ),
                                          content: const Text(
                                            'Do you want to duplicate this control?\n\nType, Make, Model, and Location will be copied.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('No'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
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
                              details: [
                                if (location.isNotEmpty)
                                  AppEntityDetail(
                                    icon: Icons.location_on,
                                    label: location,
                                  ),
                              ],
                            );

                            if (_readOnly) return card;

                            return Dismissible(
                              key: Key(
                                'communal_control_${(item['id'] ?? index).toString()}',
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) {
                                return _confirmDeleteDialog(
                                  'Delete Control',
                                  'Are you sure you want to delete this Communal Control?',
                                );
                              },
                              onDismissed: (direction) async {
                                final id = (item['id'] ?? '').toString().trim();
                                if (id.isEmpty) return;

                                final nextItems = _items
                                    .where(
                                      (x) => (x['id'] ?? '').toString() != id,
                                    )
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList(growable: true);
                                _emitItems(nextItems);
                                if (!mounted) return;
                                setState(() => _items = nextItems);
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
