import 'package:flutter/material.dart';
import '../../../components/app_info_panel.dart';
import '../../../components/form_widgets.dart';

import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/screens/meter_list_screen.dart';

class MeteringDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  const MeteringDetailsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
  });

  @override
  State<MeteringDetailsScreen> createState() => _MeteringDetailsScreenState();
}

class _MeteringDetailsScreenState extends State<MeteringDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _bulkMetersKey = 'bulkHeatMeters';
  static const _blockMetersKey = 'blockHeatMeters';

  List<Map<String, dynamic>> _readMeters(String key) {
    final raw = widget.formData[key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  void _writeMeters(String key, List<Map<String, dynamic>> meters) {
    widget.onDataChanged(key, meters);
  }

  Future<void> _editMetersInMemory({
    required String key,
    required String title,
  }) async {
    final meters = _readMeters(key);

    Future<void> addOrEdit({Map<String, dynamic>? existing, int? index}) async {
      final makeController = TextEditingController(
        text: (existing?['make'] ?? '').toString(),
      );
      final modelController = TextEditingController(
        text: (existing?['model'] ?? '').toString(),
      );
      final locationController = TextEditingController(
        text: (existing?['location'] ?? '').toString(),
      );
      final ageRangeController = TextEditingController(
        text: (existing?['ageRange'] ?? '').toString(),
      );
      final serialController = TextEditingController(
        text: (existing?['serialNumber'] ?? '').toString(),
      );
      final readingController = TextEditingController(
        text: (existing?['reading'] ?? '').toString(),
      );
      String operational = (existing?['operational'] ?? 'YES').toString();

      final saved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Meter' : 'Edit Meter'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    controller: ageRangeController,
                    decoration: const InputDecoration(labelText: 'Age Range'),
                  ),
                  TextField(
                    controller: serialController,
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                    ),
                  ),
                  TextField(
                    controller: readingController,
                    decoration: const InputDecoration(labelText: 'Reading'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: operational,
                    decoration: const InputDecoration(labelText: 'Operational'),
                    items: const [
                      DropdownMenuItem(value: 'YES', child: Text('YES')),
                      DropdownMenuItem(value: 'NO', child: Text('NO')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      operational = v;
                    },
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
          );
        },
      );

      if (saved != true) {
        makeController.dispose();
        modelController.dispose();
        locationController.dispose();
        serialController.dispose();
        readingController.dispose();
        return;
      }

      final next = <String, dynamic>{
        'make': makeController.text.trim(),
        'model': modelController.text.trim(),
        'location': locationController.text.trim(),
        'ageRange': ageRangeController.text.trim(),
        'serialNumber': serialController.text.trim().isEmpty
            ? null
            : serialController.text.trim(),
        'reading': readingController.text.trim().isEmpty
            ? null
            : readingController.text.trim(),
        'operational': operational,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      };

      setState(() {
        if (index != null && index >= 0 && index < meters.length) {
          meters[index] = next;
        } else {
          meters.add(next);
        }
        _writeMeters(key, meters);
      });

      makeController.dispose();
      modelController.dispose();
      locationController.dispose();
      ageRangeController.dispose();
      serialController.dispose();
      readingController.dispose();
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: meters.isEmpty
                    ? const Text('No meters captured')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: meters.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = meters[i];
                          final make = (m['make'] ?? '').toString();
                          final model = (m['model'] ?? '').toString();
                          final location = (m['location'] ?? '').toString();
                          final title = [
                            make,
                            model,
                          ].where((s) => s.isNotEmpty).join(' ');
                          return ListTile(
                            title: Text(title.isEmpty ? 'Meter' : title),
                            subtitle: location.isEmpty ? null : Text(location),
                            onTap: () async {
                              await addOrEdit(existing: m, index: i);
                              setLocalState(() {});
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  meters.removeAt(i);
                                  _writeMeters(key, meters);
                                });
                                setLocalState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await addOrEdit();
                    setLocalState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _networkType =>
      widget.formData['meetsHeatNetworkDefinition'] as String? ?? '';

  String get _questionText {
    if (_networkType == 'District Heat Network') {
      return 'Is there a heat meter at the point where heat enters the site?';
    }
    return 'Is a bulk generation meter fitted?';
  }

  void _onManageMeters() {
    if (widget.formId == null) {
      _editMetersInMemory(key: _bulkMetersKey, title: 'Bulk Heat Meters');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MeterListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': widget.formId,
            'networkType': 'Bulk Heat Meter',
          },
        ),
      ),
    );
  }

  void _onManageBlockMeters() {
    if (widget.formId == null) {
      _editMetersInMemory(key: _blockMetersKey, title: 'Block Level Meters');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MeterListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': widget.formId,
            'networkType': 'Block Level Meter',
          },
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final isDistrict = _networkType == 'District Heat Network';
    final title = isDistrict
        ? 'District Heat Network – Inlet (Point-of-Entry) Heat Meter'
        : 'Communal Heat Network – Bulk Generation Heat Meter';

    final bullets = isDistrict
        ? [
            'Measures total heat supplied to the site from an external heat network',
            'Located at the point where heat enters the site (typically via a PHEX)',
            'Used for overall site billing or monitoring',
            'Does not measure individual plant or dwelling consumption',
          ]
        : [
            'Measures total heat output of the communal system',
            'Serves more than one heat-generating appliance, or the combined system outlet',
            'Installed on the common distribution pipework serving the site',
            'Does not measure individual boilers or heat pumps',
          ];

    return AppInfoPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets.map((text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(text)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockInfoPanel(BuildContext context) {
    const title = 'Block-Level Heat Meter';
    const bullets = [
      'Measures heat supplied to a single building or block within the site',
      'Installed on the distribution pipework feeding that block',
      'Used to apportion heat between blocks, not individual dwellings',
      'Typically located downstream of the bulk / inlet heat meter',
    ];

    return AppInfoPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets.map((text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(text)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Bulk Generation Meters',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _questionText,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      AppSelectionCard(
                        title: 'Yes',
                        subtitle: 'Meter is fitted',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        selected: widget.formData['hasBulkMeter'] == 'Yes',
                        onTap: () =>
                            widget.onDataChanged('hasBulkMeter', 'Yes'),
                      ),
                      AppSelectionCard(
                        title: 'No',
                        subtitle: 'No meter fitted',
                        icon: Icons.highlight_off,
                        color: Colors.grey,
                        selected: widget.formData['hasBulkMeter'] == 'No',
                        onTap: () => widget.onDataChanged('hasBulkMeter', 'No'),
                      ),
                      if (widget.formData['hasBulkMeter'] == 'Yes') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _onManageMeters,
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Capture Meter Info'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildInfoPanel(context),

                      // Block Level Meters Section
                      if ((widget.formData['numBlocks'] as int? ?? 0) > 1) ...[
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Block Level Meters',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Are block level meters fitted?',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        AppSelectionCard(
                          title: 'Yes',
                          subtitle: 'Meters are fitted',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          selected: widget.formData['hasBlockMeters'] == 'Yes',
                          onTap: () =>
                              widget.onDataChanged('hasBlockMeters', 'Yes'),
                        ),
                        AppSelectionCard(
                          title: 'No',
                          subtitle: 'No meters fitted',
                          icon: Icons.highlight_off,
                          color: Colors.grey,
                          selected: widget.formData['hasBlockMeters'] == 'No',
                          onTap: () =>
                              widget.onDataChanged('hasBlockMeters', 'No'),
                        ),
                        if (widget.formData['hasBlockMeters'] == 'Yes') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _onManageBlockMeters,
                              icon: const Icon(Icons.list_alt),
                              label: const Text('Capture Meter Info'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildBlockInfoPanel(context),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
