import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';

class HeatNetworkDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  const HeatNetworkDetailsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
  });

  @override
  State<HeatNetworkDetailsScreen> createState() =>
      _HeatNetworkDetailsScreenState();
}

class _HeatNetworkDetailsScreenState extends State<HeatNetworkDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _networkNameController;

  @override
  void initState() {
    super.initState();
    _networkNameController = TextEditingController(
      text: widget.formData['networkName'] ?? '',
    );
    _networkNameController.addListener(() {
      if (_networkNameController.text !=
          (widget.formData['networkName'] ?? '')) {
        widget.onDataChanged('networkName', _networkNameController.text);
      }
    });
  }

  @override
  void didUpdateWidget(HeatNetworkDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData['networkName'] != _networkNameController.text) {
      _networkNameController.text = widget.formData['networkName'] ?? '';
    }
  }

  @override
  void dispose() {
    _networkNameController.dispose();
    super.dispose();
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
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Heat Network Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Enter basic information about the heat network',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppTextField(
                          label: 'Network Name',
                          controller: _networkNameController,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: AppLabel(label: 'Heating Type'),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            AppSelectionCard(
                              title: 'District Heating',
                              subtitle:
                                  'Heat generated centrally and distributed to multiple buildings',
                              icon: Icons.location_city,
                              color: Colors.orange,
                              selected:
                                  widget.formData['heatingType'] ==
                                  'District Heating',
                              onTap: () => widget.onDataChanged(
                                'heatingType',
                                'District Heating',
                              ),
                            ),
                            AppSelectionCard(
                              title: 'Communal Heating',
                              subtitle:
                                  'Heat generated within the building (e.g., basement boiler)',
                              icon: Icons.apartment,
                              color: Colors.blue,
                              selected:
                                  widget.formData['heatingType'] ==
                                  'Communal Heating',
                              onTap: () => widget.onDataChanged(
                                'heatingType',
                                'Communal Heating',
                              ),
                            ),
                            AppSelectionCard(
                              title: 'Combined Heat & Power',
                              subtitle:
                                  'Electricity and heat generated simultaneously',
                              icon: Icons.bolt,
                              color: Colors.purple,
                              selected:
                                  widget.formData['heatingType'] ==
                                  'Combined Heat & Power',
                              onTap: () => widget.onDataChanged(
                                'heatingType',
                                'Combined Heat & Power',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Space for fixed buttons
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
                  child: AppButton(
                    text: 'Next',
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onNext();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
