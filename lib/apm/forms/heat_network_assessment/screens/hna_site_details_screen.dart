import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';

class HNASiteDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final int? formId;

  /// Client catalog, resolved by the parent via the injected repository
  /// (SQLite on mobile, the editor payload on web) — one path for both.
  final List<String> clients;

  const HNASiteDetailsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    this.formId,
    this.clients = const <String>[],
  });

  @override
  State<HNASiteDetailsScreen> createState() => _HNASiteDetailsScreenState();
}

class _HNASiteDetailsScreenState extends State<HNASiteDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uprpnController = TextEditingController();
  final _siteNameController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _townCityController = TextEditingController();
  final _postcodeController = TextEditingController();

  bool _uprpnEnabled = false;
  DateTime? _inspectionDate;
  String? _selectedClient;

  // Dynamic lists loaded from database
  List<String> _clients = [];
  bool _isLoadingData = true;

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Load existing form data if any
    _uprpnEnabled = widget.formData['uprpnEnabled'] ?? false;
    _uprpnController.text = widget.formData['uprpn'] ?? '';
    // Maps to auditDate in backend/form_data for consistency, but displayed as Inspection Date
    _inspectionDate = _readDate(widget.formData['auditDate']) ?? DateTime.now();
    _selectedClient = widget.formData['client'];
    _siteNameController.text = _toCamelCase(widget.formData['siteName'] ?? '');
    _streetAddressController.text = _toCamelCase(
      widget.formData['streetAddress'] ?? '',
    );
    _townCityController.text = _toCamelCase(widget.formData['townCity'] ?? '');
    _postcodeController.text = (widget.formData['postcode'] ?? '')
        .toString()
        .toUpperCase();
    _applyClients(initial: true);
  }

  @override
  void didUpdateWidget(covariant HNASiteDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.clients, oldWidget.clients)) {
      _applyClients();
    }
  }

  /// Build the dropdown's item list from the injected [clients], keeping the
  /// current selection present even if the catalog doesn't contain it (so the
  /// dropdown never hits "value not in items"). Resilient to the catalog
  /// arriving after first build (async repo load).
  void _applyClients({bool initial = false}) {
    final normalized =
        widget.clients
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final selected = _selectedClient?.trim();
    if (selected != null &&
        selected.isNotEmpty &&
        !normalized.contains(selected)) {
      normalized.add(selected);
      normalized.sort();
    }

    _clients = normalized;
    _selectedClient = (selected != null && selected.isNotEmpty)
        ? selected
        : null;
    _isLoadingData = false;
    if (!initial && mounted) setState(() {});
  }

  String _toCamelCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _formatStreetAddress() {
    final text = _streetAddressController.text;
    if (text.isNotEmpty) {
      setState(() {
        _streetAddressController.text = _toCamelCase(text);
      });
    }
  }

  void _formatTownCity() {
    final text = _townCityController.text;
    if (text.isNotEmpty) {
      setState(() {
        _townCityController.text = _toCamelCase(text);
      });
    }
  }

  void _formatSiteName() {
    final text = _siteNameController.text;
    if (text.isNotEmpty) {
      setState(() {
        _siteNameController.text = _toCamelCase(text);
      });
    }
  }

  void _formatPostcode() {
    final text = _postcodeController.text;
    if (text.isNotEmpty) {
      setState(() {
        _postcodeController.text = text.toUpperCase();
      });
    }
  }

  @override
  void dispose() {
    _uprpnController.dispose();
    _siteNameController.dispose();
    _streetAddressController.dispose();
    _townCityController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      // Save all form data
      widget.onDataChanged('uprpnEnabled', _uprpnEnabled);
      widget.onDataChanged('uprpn', _uprpnController.text);
      widget.onDataChanged('auditDate', _inspectionDate);
      widget.onDataChanged('client', _selectedClient);
      widget.onDataChanged('siteName', _siteNameController.text);
      widget.onDataChanged('streetAddress', _streetAddressController.text);
      widget.onDataChanged('townCity', _townCityController.text);
      widget.onDataChanged('postcode', _postcodeController.text);

      // Move to next screen
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SECTION 1: Inspection Details
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
                          'Inspection Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormField<DateTime>(
                        validator: (_) {
                          if (_inspectionDate == null) {
                            return 'Please select inspection date';
                          }
                          return null;
                        },
                        builder: (formFieldState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppDateField(
                                label: 'Inspection Date',
                                selectedDate: _inspectionDate,
                                onDateSelected: (date) {
                                  setState(() {
                                    _inspectionDate = date;
                                  });
                                  formFieldState.didChange(date);
                                },
                              ),
                              if (formFieldState.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 4,
                                  ),
                                  child: Text(
                                    formFieldState.errorText!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      AppDropdown<String>(
                        key: ValueKey(_clients.length),
                        label: 'Client',
                        value: _selectedClient,
                        items: _clients.map((client) {
                          return DropdownMenuItem(
                            value: client,
                            child: Text(client),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClient = value;
                          });
                        },
                        validator: (value) {
                          if (_clients.isEmpty) return null;
                          if (value == null) {
                            return 'Please select a client';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SECTION 2: Site Details
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
                          'Site Details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // UPRN with toggle (Moved from top)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'UPRN?',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(width: 16),
                            Switch(
                              value: _uprpnEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _uprpnEnabled = value;
                                  if (!value) {
                                    _uprpnController.clear();
                                  }
                                });
                              },
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.8),
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              inactiveThumbColor: Colors.grey[400],
                              inactiveTrackColor: Colors.grey[200],
                              trackOutlineColor:
                                  WidgetStateProperty.resolveWith<Color?>((
                                    Set<WidgetState> states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.transparent;
                                    }
                                    return Colors.grey[300];
                                  }),
                            ),
                          ],
                        ),
                      ),
                      if (_uprpnEnabled) ...[
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Site UPRN',
                          hint: 'Enter UPRN',
                          controller: _uprpnController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Site Name/Number',
                        hint: 'Enter site name or number',
                        controller: _siteNameController,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _toCamelCase(newValue.text);
                            return newValue.copyWith(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        onEditingComplete: _formatSiteName,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter site name/number';
                          }
                          return null;
                        },
                      ),
                      AppTextField(
                        label: 'Street Address',
                        hint: 'Enter street address',
                        controller: _streetAddressController,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _toCamelCase(newValue.text);
                            return newValue.copyWith(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        onEditingComplete: _formatStreetAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter street address';
                          }
                          return null;
                        },
                      ),
                      AppTextField(
                        label: 'Town/City',
                        hint: 'Enter town or city',
                        controller: _townCityController,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _toCamelCase(newValue.text);
                            return newValue.copyWith(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        onEditingComplete: _formatTownCity,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter town/city';
                          }
                          return null;
                        },
                      ),
                      AppTextField(
                        label: 'Postcode',
                        hint: 'Enter postcode',
                        controller: _postcodeController,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = newValue.text.toUpperCase();
                            return newValue.copyWith(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        onEditingComplete: _formatPostcode,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter postcode';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Space for fixed button
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
            child: AppButton(
              text: 'Next',
              onPressed: _saveAndContinue,
              fullWidth: true,
            ),
          ),
        ),
      ],
    );
  }
}
