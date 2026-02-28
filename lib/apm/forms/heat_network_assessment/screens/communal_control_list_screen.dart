import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../models/communal_control.dart';
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
  List<CommunalControl> _items = [];
  int? _formId;
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
    final items = await DatabaseHelper.instance.getCommunalControls(_formId!);

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCommunalControlScreen(),
        settings: RouteSettings(arguments: {'formId': _formId}),
      ),
    ).then((_) => _loadItems());
  }

  void _editItem(CommunalControl item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCommunalControlScreen(),
        settings: RouteSettings(
          arguments: {'formId': _formId, 'control': item},
        ),
      ),
    ).then((_) => _loadItems());
  }

  Future<void> _duplicateItem(CommunalControl item) async {
    final newItem = CommunalControl(
      formId: item.formId,
      controlType: item.controlType,
      location: item.location,
      make: item.make,
      model: item.model,
      serialNumber: null,
      condition: null,
      operational: null,
      imagePaths: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCommunalControlScreen(),
        settings: RouteSettings(
          arguments: {'formId': _formId, 'control': newItem},
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
                            final title = item.controlType;
                            final subtitle =
                                '${item.make ?? ''} ${item.model ?? ''}'.trim();

                            final card = AppEntityCard(
                              title: title,
                              subtitle: subtitle,
                              imagePaths: item.imagePaths,
                              onTap: () => _editItem(item),
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
                                if (item.location?.isNotEmpty == true)
                                  AppEntityDetail(
                                    icon: Icons.location_on,
                                    label: item.location!,
                                  ),
                              ],
                            );

                            if (_readOnly) return card;

                            return Dismissible(
                              key: Key('communal_control_${item.id ?? index}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) {
                                return _confirmDeleteDialog(
                                  'Delete Control',
                                  'Are you sure you want to delete this Communal Control?',
                                );
                              },
                              onDismissed: (direction) async {
                                if (item.id != null) {
                                  await DatabaseHelper.instance
                                      .deleteCommunalControl(item.id!);
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
