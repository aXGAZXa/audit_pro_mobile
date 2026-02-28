import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../models/heat_meter.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/entity_card.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/screens/add_heat_meter_screen.dart';

class MeterListScreen extends StatefulWidget {
  const MeterListScreen({super.key});

  @override
  State<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends State<MeterListScreen> {
  List<HeatMeter> _meters = [];
  int? _formId;
  String? _meterType; // 'Bulk Meter' or 'Block Level Meter'
  bool _readOnly = false;
  bool _isLoading = true;
  String get _title => _readOnly
      ? 'All Heat Meters'
      : (_meterType != null ? '${_meterType}s' : 'Heat Meters');
  final String _addButtonLabel = 'Add Meter';
  final String _emptyStateLabel = 'No Heat Meters';

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
    if (_formId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _formId = args['formId'] as int?;
        _meterType =
            args['networkType']
                as String?; // Args passed as 'networkType' upstream
        _readOnly = args['readOnly'] as bool? ?? false;
        _loadMeters();
      }
    }
  }

  Future<void> _loadMeters() async {
    if (_formId == null) return;

    setState(() => _isLoading = true);
    // Get all heat meters for this form
    final allMeters = await DatabaseHelper.instance.getHeatMeters(_formId!);

    // Filter by meter type if necessary?
    // The previous implementation assumed "Assets" were filtered or just all assets.
    // The requirement is to have context.
    // However, the `heat_meters` table has `meter_type` column.
    // So we SHOULD filter by `_meterType`.

    final filteredMeters = _meterType != null && !_readOnly
        ? allMeters.where((m) {
            // Check for exact match OR match with brackets (e.g. "Block Level Meter (Block A)")
            if (m.meterType == _meterType) return true;
            if (m.meterType.startsWith('$_meterType (')) return true;
            return false;
          }).toList()
        : allMeters;

    setState(() {
      _meters = filteredMeters;
      _isLoading = false;
    });
  }

  void _addMeter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {'formId': _formId, 'meterType': _meterType},
        ),
      ),
    ).then((_) => _loadMeters());
  }

  void _editMeter(HeatMeter meter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHeatMeterScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': _formId,
            'meter': meter,
            'meterType': _meterType,
          },
        ),
      ),
    ).then((_) => _loadMeters());
  }

  Future<void> _duplicateMeter(HeatMeter meter) async {
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
      // Create new meter object copy without ID and specific unique fields
      final duplicatedMeter = HeatMeter(
        formId: _formId!,
        meterType: _meterType!,
        make: meter.make,
        model: meter.model,
        location: meter.location,
        ageRange: meter.ageRange,
        serialNumber: null, // Clear serial
        operational:
            'YES', // Reset operational default? Or copy? Let's reset to force check.
        reading: null,
        imagePaths: [], // Do not copy images
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddHeatMeterScreen(),
          settings: RouteSettings(
            arguments: {
              'formId': _formId,
              'meter': duplicatedMeter,
              'meterType': _meterType,
            },
          ),
        ),
      ).then((_) => _loadMeters());
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
                            final title = '${meter.make} ${meter.model}';

                            final card = AppEntityCard(
                              title: title.trim().isEmpty
                                  ? 'Unknown Meter'
                                  : title,
                              subtitle: meter.meterType,
                              imagePaths: meter.imagePaths,
                              details: [
                                if (meter.serialNumber != null &&
                                    meter.serialNumber!.isNotEmpty)
                                  Text(
                                    'S/N: ${meter.serialNumber}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                if (meter.location.isNotEmpty)
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
                                          meter.location,
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
                              key: Key('heat_meter_${meter.id ?? index}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) =>
                                  _confirmDeleteDialog(),
                              onDismissed: (direction) async {
                                if (meter.id != null) {
                                  await DatabaseHelper.instance.deleteHeatMeter(
                                    meter.id!,
                                  );
                                  _loadMeters();
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
