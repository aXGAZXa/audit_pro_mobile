import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/app_scaffold.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_reference_data_service.dart';
import 'package:audit_pro_mobile/apm/forms/heat_network_assessment/services/hna_submission_service.dart';
import 'package:audit_pro_mobile/logging/apm_logger.dart';
import 'package:audit_pro_mobile/apm/services/app_info_service.dart';
import 'package:audit_pro_mobile/apm/services/auth_token_store.dart';
import 'package:audit_pro_mobile/apm/services/portal_api_client.dart';
import 'package:audit_pro_mobile/apm/config/api_config.dart';
import 'screens/hna_site_details_screen.dart';
import 'screens/development_details_screen.dart';
import 'screens/metering_details_screen.dart';
import 'screens/heat_generators_screen.dart';
import 'screens/dwelling_inspections_summary_screen.dart';
import 'screens/assessment_summary_screen.dart';
import 'screens/hna_summary_signature_screen.dart';
import 'screens/hna_unsafe_situations_screen.dart';

class HeatNetworkAssessmentScreen extends StatefulWidget {
  final int? formId;
  final bool forceNew;

  const HeatNetworkAssessmentScreen({
    super.key,
    this.formId,
    this.forceNew = false,
  });

  @override
  State<HeatNetworkAssessmentScreen> createState() =>
      _HeatNetworkAssessmentScreenState();
}

class _HeatNetworkAssessmentScreenState
    extends State<HeatNetworkAssessmentScreen> {
  final PageController _pageController = PageController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final HnaSubmissionService _submissionService = HnaSubmissionService(
    tokenStore: AuthTokenStore(),
    appInfoService: AppInfoService(),
  );

  int _currentPage = 0;
  int? _formId;
  int _clientsSyncNonce = 0;

  final Map<String, dynamic> _formData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ApmLogger.info(
      'initState formId=${widget.formId} forceNew=${widget.forceNew}',
      category: 'HNA/Startup',
    );
    _loadOrCreateForm();
  }

  Future<void> _syncClientsBestEffort() async {
    ApmLogger.info(
      'Client sync start formId=$_formId baseUrl=${ApiConfig.portalBaseUrl}',
      category: 'HNA/Startup',
    );
    try {
      final svc = HnaReferenceDataService(
        tokenStore: AuthTokenStore(),
        apiClient: PortalApiClient(baseUrl: ApiConfig.portalBaseUrl),
        db: _db,
      );
      await svc.syncClientsIfSignedIn();
      if (mounted) {
        setState(() => _clientsSyncNonce++);
        ApmLogger.info(
          'Client sync complete formId=$_formId clientsSyncNonce=$_clientsSyncNonce',
          category: 'HNA/Startup',
        );
      }
    } catch (e, st) {
      ApmLogger.warning(
        'Client sync failed formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
      // Best-effort: offline or not signed in should not block form usage.
    }
  }

  Future<void> _loadOrCreateForm() async {
    setState(() => _isLoading = true);

    ApmLogger.info(
      'LoadOrCreate start formId=${widget.formId} forceNew=${widget.forceNew}',
      category: 'HNA/Startup',
    );

    try {
      if (widget.formId != null) {
        final form = await _db.getForm(widget.formId!);
        if (form != null) {
          _formId = form['id'];
          ApmLogger.info(
            'Loaded form by id formId=$_formId status=${form['status']}',
            category: 'HNA/Startup',
          );

          final status = form['status']?.toString() ?? '';
          if (status == 'draft' && _formId != null) {
            await _db.setCurrentFormId(
              formType: 'heat_network_assessment',
              formId: _formId!,
            );
          }

          final formData = form['form_data'] as Map<String, dynamic>;
          _formData.clear();
          formData.forEach((key, value) {
            _formData[key] = _convertFromSerializable(value);
          });
          if (mounted) setState(() => _isLoading = false);
          await _syncClientsBestEffort();
          return;
        }

        ApmLogger.info(
          'No form found for explicit id formId=${widget.formId}',
          category: 'HNA/Startup',
        );
      }

      if (!widget.forceNew) {
        final currentId = await _db.getCurrentFormId('heat_network_assessment');

        if (currentId != null) {
          final currentForm = await _db.getForm(currentId);
          if (currentForm != null) {
            final status = currentForm['status']?.toString() ?? '';
            if (status == 'draft') {
              _formId = currentForm['id'];
              ApmLogger.info(
                'Resuming current draft form formId=$_formId',
                category: 'HNA/Startup',
              );
              final loadedData =
                  currentForm['form_data'] as Map<String, dynamic>;
              _formData.addAll(_convertFromSerializable(loadedData));
              if (mounted) setState(() => _isLoading = false);
              await _syncClientsBestEffort();
              return;
            }

            ApmLogger.info(
              'Current form is not draft (status=$status). Starting new.',
              category: 'HNA/Startup',
            );
          }

          // Current pointer is stale or no longer a draft.
          await _db.clearCurrentFormId('heat_network_assessment');
        }
      }

      // Create new form in database (either forceNew=true or no existing forms)
      final id = await _db.saveForm(
        formType: 'heat_network_assessment',
        status: 'draft',
        formData: {},
      );
      _formId = id;
      await _db.setCurrentFormId(
        formType: 'heat_network_assessment',
        formId: id,
      );
      ApmLogger.info(
        'Created new form formId=$_formId',
        category: 'HNA/Startup',
      );
      if (mounted) setState(() => _isLoading = false);
      await _syncClientsBestEffort();
    } catch (e, st) {
      ApmLogger.warning(
        'Error loading form: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  dynamic _convertFromSerializable(dynamic value) {
    if (value is String) {
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) {
          return DateTime.parse(value);
        }
      } catch (_) {}
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (e) => MapEntry(e.key.toString(), _convertFromSerializable(e.value)),
        ),
      );
    }
    return value;
  }

  dynamic _convertToSerializable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            _convertToSerializable(entry.value),
          ),
        ),
      );
    }
    return value;
  }

  void _updateFormData(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
    _saveForm(status: 'draft'); // Autosave
  }

  Future<void> _saveForm({String status = 'draft'}) async {
    if (_formId == null) return;
    try {
      final dataToSave = _convertToSerializable(_formData);
      await _db.saveForm(
        id: _formId,
        formType: 'heat_network_assessment',
        status: status,
        formData: dataToSave,
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Error saving form formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Startup',
        error: e,
        stackTrace: st,
      );
    }
  }

  List<Widget> _buildPages() {
    final isNetwork = [
      'District Heat Network',
      'Communal Heat Network',
    ].contains(_formData['meetsHeatNetworkDefinition']);

    final shouldShowGenerators =
        _formData['meetsHeatNetworkDefinition'] != 'In-Flat Generation' &&
        _formData['meetsHeatNetworkDefinition'] != null;

    return [
      HNASiteDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        formId: _formId,
        clientsSyncNonce: _clientsSyncNonce,
      ),
      DevelopmentDetailsScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
      ),
      if (isNetwork)
        MeteringDetailsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: _nextPage,
          onBack: _previousPage,
          formId: _formId,
        ),
      if (shouldShowGenerators)
        HeatGeneratorsScreen(
          formData: _formData,
          onDataChanged: _updateFormData,
          onNext: _nextPage,
          onBack: _previousPage,
          formId: _formId,
        ),
      DwellingInspectionsSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
      ),
      HNAUnsafeSituationsScreen(
        formData: _formData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
      ),
      AssessmentSummaryScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onNext: _nextPage,
        onBack: _previousPage,
        formId: _formId,
      ),
      HNASummarySignatureScreen(
        formData: _formData,
        onDataChanged: _updateFormData,
        onBack: _previousPage,
        onComplete: () {
          _completeAndSubmit();
        },
        formId: _formId,
      ),
    ];
  }

  Future<void> _completeAndSubmit() async {
    if (_formId == null) return;

    ApmLogger.info(
      'Complete+Submit start formId=$_formId',
      category: 'HNA/Submit',
    );

    // Once the user submits (even if it fails), we stop treating this as the
    // in-progress draft. It will remain in My Forms as pending for retry.
    await _db.clearCurrentFormId('heat_network_assessment');

    await _saveForm(status: 'pending');
    if (!mounted) return;

    try {
      await _submissionService.submitForm(formId: _formId!);
      ApmLogger.info(
        'Complete+Submit success formId=$_formId',
        category: 'HNA/Submit',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form submitted.')));
      Navigator.of(context).pop();
    } catch (e, st) {
      ApmLogger.warning(
        'Complete+Submit failed formId=$_formId: {Error}',
        args: [e.toString()],
        category: 'HNA/Submit',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed. Saved to My Forms for retry.\n$e'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _previousPage() async {
    _saveForm();
    if (_currentPage > 0) {
      final pages = _buildPages();
      // Check if previous page is UnsafeSituationsScreen and should be skipped
      if (_currentPage - 1 >= 0 &&
          pages[_currentPage - 1] is HNAUnsafeSituationsScreen &&
          _formId != null) {
        final unsafeObservations = await _db.getUnsafeObservations(_formId!);
        if (unsafeObservations.isEmpty) {
          // Skip back 2 pages
          if (_currentPage - 2 >= 0) {
            _pageController.animateToPage(
              _currentPage - 2,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            return;
          }
        }
      }

      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() async {
    final pages = _buildPages();

    if (_currentPage < pages.length - 1) {
      _saveForm();

      // Check if next page is UnsafeSituationsScreen and should be skipped
      if (_currentPage + 1 < pages.length &&
          pages[_currentPage + 1] is HNAUnsafeSituationsScreen &&
          _formId != null) {
        final unsafeObservations = await _db.getUnsafeObservations(_formId!);
        if (unsafeObservations.isEmpty) {
          // Skip forward 2 pages to (Unsafe + 1)
          if (_currentPage + 2 < pages.length) {
            _pageController.animateToPage(
              _currentPage + 2,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            return;
          }
        }
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete ?
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Heat Network Assessment',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = _buildPages();

    return AppScaffold(
      title: 'Heat Network Assessment',
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: pages,
      ),
    );
  }
}
