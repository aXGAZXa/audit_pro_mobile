import 'package:flutter/material.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/entity_card.dart';
import 'add_dwelling_inspection_screen.dart';

class DwellingInspectionListScreen extends StatefulWidget {
  const DwellingInspectionListScreen({super.key});

  @override
  State<DwellingInspectionListScreen> createState() =>
      _DwellingInspectionListScreenState();
}

class _DwellingInspectionListScreenState
    extends State<DwellingInspectionListScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;
  List<Map<String, dynamic>>? _observationsJson;
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;
  bool _isLoading = true;
  bool _readOnly = false;
  final String _title = 'Dwelling Inspections';
  final String _addButtonLabel = 'Add Dwelling Inspection';
  final String _emptyStateLabel = 'No Dwelling Inspections';

  Future<bool> _confirmDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inspection'),
        content: const Text(
          'Are you sure you want to delete this Dwelling Inspection?',
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

    final raw = assets['dwellingInspections'];
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
    nextAssets['dwellingInspections'] = nextItems;
    _assetsJson = nextAssets;
    onAssetsChanged(nextAssets);
  }

  Future<void> _addItem() async {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    final observations = _observationsJson;
    final onObservationsChanged = _onObservationsChanged;
    if (assets == null || onAssetsChanged == null) return;

    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDwellingInspectionScreen(),
        settings: RouteSettings(
          arguments: {
            'assetsJson': assets,
            'onAssetsChanged': onAssetsChanged,
            'observationsJson': observations ?? const <Map<String, dynamic>>[],
            'onObservationsChanged': onObservationsChanged,
          },
        ),
      ),
    );

    if (saved == null) return;

    final next = List<Map<String, dynamic>>.from(_items);
    final id = (saved['id'] ?? '').toString();
    final idx = next.indexWhere((m) => (m['id'] ?? '').toString() == id);
    if (idx >= 0) {
      next[idx] = saved;
    } else {
      next.add(saved);
    }

    setState(() => _items = next);
    _emitItems(next);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    final observations = _observationsJson;
    final onObservationsChanged = _onObservationsChanged;
    if (assets == null || onAssetsChanged == null) return;

    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDwellingInspectionScreen(),
        settings: RouteSettings(
          arguments: {
            'assetsJson': assets,
            'onAssetsChanged': onAssetsChanged,
            'inspection': item,
            'observationsJson': observations ?? const <Map<String, dynamic>>[],
            'onObservationsChanged': onObservationsChanged,
          },
        ),
      ),
    );

    if (saved == null) return;

    final next = List<Map<String, dynamic>>.from(_items);
    final id = (saved['id'] ?? '').toString();
    final idx = next.indexWhere((m) => (m['id'] ?? '').toString() == id);
    if (idx >= 0) {
      next[idx] = saved;
    } else {
      next.add(saved);
    }

    setState(() => _items = next);
    _emitItems(next);
  }

  Future<void> _duplicateItem(Map<String, dynamic> item) async {
    final newItem = <String, dynamic>{
      'location': item['location'],
      'heatingType': item['heatingType'],
      'heatGeneratorType': item['heatGeneratorType'],
      'heatGeneratorFuelType': item['heatGeneratorFuelType'],
      'heatDistributionType': item['heatDistributionType'],
      'dhwType': item['dhwType'],
      'dhwGeneratorType': item['dhwGeneratorType'],
      'dhwGeneratorFuelType': item['dhwGeneratorFuelType'],
      'dhwCommunalType': item['dhwCommunalType'],
      'heatingMetered': item['heatingMetered'],
      'dhwMetered': item['dhwMetered'],
      'hiuMake': item['hiuMake'],
      'hiuModel': item['hiuModel'],
      'hiuSerialNumber': null,
      'condition': null,
      'operational': null,
      'imagePaths': <String>[],
      'heatingControls': <String>[],
      'heatingControlsOther': null,
      'heatingNotes': null,
      'heatingImagePaths': <String>[],
      'dhwControls': <String>[],
      'dhwControlsOther': null,
      'dhwNotes': null,
      'dhwImagePaths': <String>[],
      'heatingSubMeterFeasible': null,
      'heatingSubMeterFeasibilityReason': null,
      'heatingSubMeterEvidenceImages': <String>[],
      'dhwSubMeterFeasible': null,
      'dhwSubMeterFeasibilityReason': null,
      'dhwSubMeterEvidenceImages': <String>[],
    };

    final assets = _assetsJson;
    final onAssetsChanged = _onAssetsChanged;
    final observations = _observationsJson;
    final onObservationsChanged = _onObservationsChanged;
    if (assets == null || onAssetsChanged == null) return;

    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDwellingInspectionScreen(),
        settings: RouteSettings(
          arguments: {
            'assetsJson': assets,
            'onAssetsChanged': onAssetsChanged,
            'inspection': newItem,
            'observationsJson': observations ?? const <Map<String, dynamic>>[],
            'onObservationsChanged': onObservationsChanged,
          },
        ),
      ),
    );

    if (saved == null) return;

    final next = List<Map<String, dynamic>>.from(_items);
    next.add(saved);

    setState(() => _items = next);
    _emitItems(next);
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
                                Icons.home,
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
                            final title = (item['location'] ?? '').toString();

                            final parts = <String>[];
                            final heatingType = (item['heatingType'] ?? '')
                                .toString()
                                .trim();
                            if (heatingType.isNotEmpty) parts.add(heatingType);

                            final heatGenType =
                                (item['heatGeneratorType'] ?? '')
                                    .toString()
                                    .trim();
                            if (heatGenType.isNotEmpty) parts.add(heatGenType);

                            final heatDist =
                                (item['heatDistributionType'] ?? '')
                                    .toString()
                                    .trim();
                            if (heatDist.isNotEmpty) parts.add(heatDist);

                            final hiuMake = (item['hiuMake'] ?? '')
                                .toString()
                                .trim();
                            if (hiuMake.isNotEmpty) parts.add(hiuMake);

                            final subtitle = parts.join(' - ');

                            final operational = (item['operational'] ?? '')
                                .toString()
                                .trim();

                            final status = operational == 'Yes'
                                ? 'Operational'
                                : 'Issue';
                            final statusColor = operational == 'Yes'
                                ? Colors.green
                                : Colors.orange;

                            final imagePathsRaw = item['imagePaths'];
                            final imagePaths = imagePathsRaw is List
                                ? imagePathsRaw
                                      .where((e) => e != null)
                                      .map((e) => e.toString())
                                      .toList(growable: false)
                                : const <String>[];

                            final card = AppEntityCard(
                              title: title,
                              subtitle: subtitle,
                              imagePaths: imagePaths,
                              onTap: () => _editItem(item),
                              actions: [
                                if (!_readOnly)
                                  AppEntityAction(
                                    icon: Icons.copy,
                                    label: 'Duplicate',
                                    onPressed: () => _duplicateItem(item),
                                  ),
                              ],
                              details: [
                                AppEntityDetail(
                                  icon: operational == 'Yes'
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  label: status,
                                  valueColor: statusColor,
                                ),
                              ],
                            );

                            if (_readOnly) return card;

                            return Dismissible(
                              key: Key(
                                'dwelling_inspection_${(item['id'] ?? index).toString()}',
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) =>
                                  _confirmDeleteDialog(),
                              onDismissed: (direction) async {
                                final next = List<Map<String, dynamic>>.from(
                                  _items,
                                );
                                final id = (item['id'] ?? '').toString();
                                next.removeWhere(
                                  (m) => (m['id'] ?? '').toString() == id,
                                );

                                setState(() => _items = next);
                                _emitItems(next);
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
