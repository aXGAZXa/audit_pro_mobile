import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';

class SiteDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final int? formId;
  final VoidCallback? onObservationsChanged;
  final bool Function(String)? hasObservations;
  final bool hidePropertyType;

  const SiteDetailsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    this.formId,
    this.onObservationsChanged,
    this.hasObservations,
    this.hidePropertyType = false,
  });

  @override
  State<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends State<SiteDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uprpnController = TextEditingController();
  final _siteNameController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _townCityController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _propertyTypeOtherController = TextEditingController();

  bool _uprpnEnabled = false;
  DateTime? _auditDate;
  String? _selectedClient;
  String? _selectedPropertyType;

  // Dynamic lists loaded from database
  List<String> _clients = [];
  List<String> _propertyTypes = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
    // Load existing form data if any
    _uprpnEnabled = widget.formData['uprpnEnabled'] ?? false;
    _uprpnController.text = widget.formData['uprpn'] ?? '';
    _auditDate = widget.formData['auditDate'] ?? DateTime.now();
    _selectedClient = widget.formData['client'];
    _selectedPropertyType = widget.formData['propertyType'];
    _siteNameController.text = widget.formData['siteName'] ?? '';
    _streetAddressController.text = widget.formData['streetAddress'] ?? '';
    _townCityController.text = widget.formData['townCity'] ?? '';
    _postcodeController.text = widget.formData['postcode'] ?? '';
    _propertyTypeOtherController.text =
        widget.formData['propertyTypeOther'] ?? '';
  }

  Future<void> _loadCollections() async {
    final db = DatabaseHelper.instance;
    final clientsData = await db.getClients();
    final propertyTypesData = await db.getPropertyTypes();

    setState(() {
      _clients = clientsData.map((c) => c['name'] as String).toList();
      _propertyTypes = propertyTypesData
          .map((p) => p['name'] as String)
          .toList();
      _isLoadingData = false;
    });
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
    _propertyTypeOtherController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      // Save all form data
      widget.onDataChanged('uprpnEnabled', _uprpnEnabled);
      widget.onDataChanged('uprpn', _uprpnController.text);
      widget.onDataChanged('auditDate', _auditDate);
      widget.onDataChanged('client', _selectedClient);
      widget.onDataChanged('propertyType', _selectedPropertyType);
      widget.onDataChanged('siteName', _siteNameController.text);
      widget.onDataChanged('streetAddress', _streetAddressController.text);
      widget.onDataChanged('townCity', _townCityController.text);
      widget.onDataChanged('postcode', _postcodeController.text);
      if (_selectedPropertyType == 'Other') {
        widget.onDataChanged(
          'propertyTypeOther',
          _propertyTypeOtherController.text,
        );
      }

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
                      // UPRN with toggle
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
                      FormField<DateTime>(
                        validator: (_) {
                          if (_auditDate == null) {
                            return 'Please select audit date';
                          }
                          return null;
                        },
                        builder: (formFieldState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppDateField(
                                label: 'Audit Date',
                                selectedDate: _auditDate,
                                onDateSelected: (date) {
                                  setState(() {
                                    _auditDate = date;
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
                          if (value == null) {
                            return 'Please select a client';
                          }
                          return null;
                        },
                      ),
                      if (!widget.hidePropertyType) ...[
                        AppDropdown<String>(
                          label: 'Property Type',
                          value: _selectedPropertyType,
                          items: _propertyTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPropertyType = value;
                              if (value != 'Other') {
                                _propertyTypeOtherController.clear();
                                widget.onDataChanged('propertyTypeOther', null);
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select property type';
                            }
                            return null;
                          },
                        ),
                        if (_selectedPropertyType == 'Other')
                          AppTextField(
                            label: 'Specify Property Type',
                            hint: 'Enter property type',
                            controller: _propertyTypeOtherController,
                            validator: (value) {
                              if (_selectedPropertyType == 'Other' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please specify property type';
                              }
                              return null;
                            },
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Site Address',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Site Name/Number',
                        hint: 'Enter site name or number',
                        controller: _siteNameController,
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
