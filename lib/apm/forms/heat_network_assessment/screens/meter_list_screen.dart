import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../database/database_helper.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/entity_card.dart';
import '../heat_network_assessment_definition.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/screens/add_heat_meter_screen.dart';

class MeterListScreen extends StatefulWidget {
  const MeterListScreen({super.key});

  @override
  State<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends State<MeterListScreen> {
  List<Map<String, dynamic>> _meters = [];
  int? _formId;
  String? _meterType; // 'Bulk Meter' or 'Block Level Meter'
  bool _readOnly = false;
  bool _isLoading = true;
  bool _didInitArgs = false;

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;

  List<Map<String, dynamic>>? _observationsJson;
  void Function(List<Map<String, dynamic>> next)? _onObservationsChanged;

  String? _relatedAssetType;
  dynamic _relatedAssetId;

  bool get _isDwellingScopedCollection {
    final relatedType = (_relatedAssetType ?? '').toString().trim();
    final relatedId = (_relatedAssetId ?? '').toString().trim();
    return relatedType == 'Dwelling Inspection' && relatedId.isNotEmpty;
  }

  String get _title => _readOnly
      ? 'All Heat Meters'
      : _isDwellingScopedCollection
      ? 'Dwelling Heat Meters'
      : (_meterType != null ? '${_meterType}s' : 'Heat Meters');
  final String _addButtonLabel = 'Add Meter';
  final String _emptyStateLabel = 'No Heat Meters';

  String? _linkedDwellingLabel(Map<String, dynamic> meter) {
    final relatedType = (meter['relatedAssetType'] ?? '').toString().trim();
    final relatedId = (meter['relatedAssetId'] ?? '').toString().trim();
    if (relatedType != 'Dwelling Inspection' || relatedId.isEmpty) {
      return null;
    }

    final assets = _assetsJson;
    if (assets == null) return 'Dwelling $relatedId';

    final raw = assets['dwellingInspections'];
    if (raw is! List) return 'Dwelling $relatedId';

    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if ((map['id'] ?? '').toString().trim() != relatedId) continue;
      final location = (map['location'] ?? '').toString().trim();
      if (location.isNotEmpty) return 'Dwelling $location';
      return 'Dwelling $relatedId';
    }

    return 'Dwelling $relatedId';
  }

  List<Map<String, dynamic>> _readHeatMeters(Map<String, dynamic> assets) {
    final raw = assets['heatMeters'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  bool _matchesType(Map<String, dynamic> m) {
    if (_readOnly) return true;
    if (_isDwellingScopedCollection) return true;
    final t = (_meterType ?? '').toString();
    if (t.isEmpty) return true;
    final meterType = (m['meterType'] ?? m['meter_type'] ?? '').toString();
    if (meterType == t) return true;
    if (meterType.startsWith('$t (')) return true;
    return false;
  }

  bool _matchesRelatedAsset(Map<String, dynamic> m) {
    final type = (_relatedAssetType ?? '').toString().trim();
    if (type.isEmpty) return true;

    final id = _relatedAssetId;
    if (id == null) return true;

    final meterType = (m['relatedAssetType'] ?? '').toString().trim();
    final meterId = (m['relatedAssetId'] ?? '').toString().trim();

    return meterType == type && meterId == id.toString().trim();
  }

  List<Map<String, dynamic>> _filteredMeters(
    List<Map<String, dynamic>> meters,
  ) {
    return meters
        .where(_matchesRelatedAsset)
        .where(_matchesType)
        .toList(growable: false);
  }

  Future<void> _loadDraftIfNeeded({bool force = false}) async {
    if (!force && _assetsJson != null) return;
    if (_formId == null) return;

    final form = await DatabaseHelper.instance.getForm(_formId!);
    if (form == null) return;

    final draft = form['form_data'];
    if (draft is! Map) return;
    final draftDoc = Map<String, dynamic>.from(draft);

    final assets = draftDoc['assets'];
    if (assets is Map) {
      _assetsJson = Map<String, dynamic>.from(assets);
    } else {
      _assetsJson = <String, dynamic>{};
    }

    final obs = draftDoc['observations'];
    if (obs is List) {
      _observationsJson = obs
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    }
  }

  Future<void> _persistAssets(Map<String, dynamic> nextAssets) async {
    _assetsJson = Map<String, dynamic>.from(nextAssets);

    final cb = _onAssetsChanged;
    if (cb != null) {
      cb(nextAssets);
      return;
    }

    // Fallback: persist into the single aggregate draft doc in the forms row.
    if (_formId == null) return;
    final form = await DatabaseHelper.instance.getForm(_formId!);
    if (form == null) return;

    final draftRaw = form['form_data'];
    if (draftRaw is! Map) return;
    final draftDoc = Map<String, dynamic>.from(draftRaw);
    draftDoc['assets'] = nextAssets;

    final status = (form['status'] ?? 'draft').toString();
    final formType = (form['form_type'] ?? kHeatNetworkAssessmentFormType)
        .toString();
    final uuid = (form['uuid'] ?? '').toString();

    await DatabaseHelper.instance.saveForm(
      id: _formId,
      formType: formType,
      status: status,
      formData: jsonDecode(jsonEncode(draftDoc)) as Map<String, dynamic>,
      uuid: uuid.isEmpty ? null : uuid,
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meter'),
        content: const Text('Are you sure you want to delete this meter?'),
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
    return confirmed == true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _didInitArgs = true;
        _formId = args['formId'] as int?;
        _meterType =
            args['networkType']
                as String?; // Args passed as 'networkType' upstream
        _readOnly = args['readOnly'] as bool? ?? false;

        _relatedAssetType = args['relatedAssetType'] as String?;
        _relatedAssetId = args['relatedAssetId'];

        final assetsArg = args['assetsJson'];
        if (assetsArg is Map) {
          _assetsJson = Map<String, dynamic>.from(assetsArg);
        }
        final cb = args['onAssetsChanged'];
        if (cb is void Function(Map<String, dynamic>)) {
          _onAssetsChanged = (nextAssets) {
            _assetsJson = Map<String, dynamic>.from(nextAssets);
            cb(nextAssets);
          };
        }

        final obsArg = args['observationsJson'];
        if (obsArg is List) {
          _observationsJson = obsArg
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true);
        }
        final onObs = args['onObservationsChanged'];
        if (onObs is void Function(List<Map<String, dynamic>>)) {
          _onObservationsChanged = (next) {
            _observationsJson = next;
            onObs(next);
          };
        }

        _loadMeters();
      }
    }
  }

  Future<void> _loadMeters() async {
    setState(() => _isLoading = true);

    // Always refresh from the persisted draft doc: downstream screens may have
    // updated the single JSON blob without updating our local in-memory copy.
    await _loadDraftIfNeeded(force: true);
    final assets = _assetsJson ?? <String, dynamic>{};
    final all = _readHeatMeters(assets);
    final filtered = _filteredMeters(all);

    setState(() {
      _meters = filtered;
      _isLoading = false;
    });
  }

  void _upsertAndRefresh(Map<String, dynamic> savedMeter) {
    final id = (savedMeter['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final allMeters = _assetsJson != null
        ? _readHeatMeters(_assetsJson!)
        : _meters
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true);

    final index = allMeters.indexWhere((m) => (m['id'] ?? '').toString() == id);
    if (index >= 0) {
      allMeters[index] = Map<String, dynamic>.from(savedMeter);
    } else {
      allMeters.add(Map<String, dynamic>.from(savedMeter));
    }

    final nextAssets = Map<String, dynamic>.from(
      _assetsJson ?? <String, dynamic>{},
    );
    nextAssets['heatMeters'] = allMeters;
    _assetsJson = nextAssets;
    _onAssetsChanged?.call(nextAssets);

    setState(() {
      _meters = _filteredMeters(allMeters);
    });
  }

  void _addMeter() {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': _formId,
            'meterType': _meterType,
            'relatedAssetType': _relatedAssetType,
            'relatedAssetId': _relatedAssetId,
            'assetsJson': _assetsJson,
            'onAssetsChanged': _onAssetsChanged,
            'observationsJson': _observationsJson,
            'onObservationsChanged': _onObservationsChanged,
          },
        ),
      ),
    ).then((saved) {
      if (saved != null) {
        _upsertAndRefresh(saved);
        return;
      }
      _loadMeters();
    });
  }

  void _editMeter(Map<String, dynamic> meter) {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': _formId,
            'meter': meter,
            'meterType': _meterType,
            'relatedAssetType': _relatedAssetType,
            'relatedAssetId': _relatedAssetId,
            'assetsJson': _assetsJson,
            'onAssetsChanged': _onAssetsChanged,
            'observationsJson': _observationsJson,
            'onObservationsChanged': _onObservationsChanged,
          },
        ),
      ),
    ).then((saved) {
      if (saved != null) {
        _upsertAndRefresh(saved);
        return;
      }
      _loadMeters();
    });
  }

  Future<void> _duplicateMeter(Map<String, dynamic> meter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Meter'),
        content: const Text(
          'Do you want to duplicate this meter?\n\nOnly Make, Model, Location, and Age will be copied.',
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
      final duplicatedMeter = <String, dynamic>{
        // No id (forces new)
        'meterType': (_meterType ?? meter['meterType'] ?? '').toString(),
        'make': (meter['make'] ?? '').toString(),
        'model': (meter['model'] ?? '').toString(),
        'location': (meter['location'] ?? '').toString(),
        'ageRange': (meter['ageRange'] ?? '').toString(),
        'serialNumber': null,
        'operational': 'YES',
        'reading': null,
        'imagePaths': <String>[],
        'relatedAssetType': meter['relatedAssetType'],
        'relatedAssetId': meter['relatedAssetId'],
      };

      if (!mounted) return;
      Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const AddHeatMeterScreen(),
          settings: RouteSettings(
            arguments: {
              'formId': _formId,
              'meter': duplicatedMeter,
              'meterType': _meterType,
              'relatedAssetType': _relatedAssetType,
              'relatedAssetId': _relatedAssetId,
              'assetsJson': _assetsJson,
              'onAssetsChanged': _onAssetsChanged,
              'observationsJson': _observationsJson,
              'onObservationsChanged': _onObservationsChanged,
            },
          ),
        ),
      ).then((saved) {
        if (saved != null) {
          _upsertAndRefresh(saved);
          return;
        }
        _loadMeters();
      });
    }
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
                      onPressed: _addMeter,
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
                  child: _meters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gas_meter_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _emptyStateLabel,
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
                          itemCount: _meters.length,
                          itemBuilder: (context, index) {
                            final meter = _meters[index];
                            final make = (meter['make'] ?? '').toString();
                            final model = (meter['model'] ?? '').toString();
                            final title = '$make $model';

                            final meterType = (meter['meterType'] ?? '')
                                .toString();
                            final imagePathsRaw = meter['imagePaths'];
                            final imagePaths = imagePathsRaw is List
                                ? imagePathsRaw
                                      .map((e) => e.toString())
                                      .toList()
                                : <String>[];

                            final serialNumber = (meter['serialNumber'] ?? '')
                                .toString();
                            final location = (meter['location'] ?? '')
                                .toString();
                            final linkedDwelling = _linkedDwellingLabel(meter);

                            final card = AppEntityCard(
                              title: title.trim().isEmpty
                                  ? 'Unknown Meter'
                                  : title,
                              subtitle: meterType,
                              imagePaths: imagePaths,
                              details: [
                                if (serialNumber.isNotEmpty)
                                  Text(
                                    'S/N: $serialNumber',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                if (location.isNotEmpty)
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
                                          location,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (linkedDwelling != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.home_outlined,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          linkedDwelling,
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
                                        onPressed: () => _duplicateMeter(meter),
                                        tooltip: 'Duplicate',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                              onTap: _readOnly ? null : () => _editMeter(meter),
                            );

                            if (_readOnly) return card;

                            return Dismissible(
                              key: Key(
                                'heat_meter_${(meter['id'] ?? index).toString()}',
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) =>
                                  _confirmDeleteDialog(),
                              onDismissed: (direction) async {
                                final current = _assetsJson;
                                if (current == null) return;

                                final id = (meter['id'] ?? '').toString();
                                if (id.isEmpty) return;
                                final nextAssets = Map<String, dynamic>.from(
                                  current,
                                );
                                final list = _readHeatMeters(nextAssets);
                                list.removeWhere(
                                  (m) => (m['id'] ?? '').toString() == id,
                                );
                                nextAssets['heatMeters'] = list;
                                await _persistAssets(nextAssets);
                                _loadMeters();
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
