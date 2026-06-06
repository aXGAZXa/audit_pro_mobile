import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audit_pro_mobile/auth/auth_storage.dart';
import 'package:audit_pro_mobile/auth/jwt_payload.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';
import 'package:audit_pro_mobile/apm/services/user_profile_store.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SummarySignatureScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final int? formId;

  /// Display label for the app user's role on this screen (e.g. "Auditor", "Assessor").
  ///
  /// Note: the underlying saved keys remain `auditorName` / `auditorSignature` for compatibility.
  final String auditorRoleLabel;

  const SummarySignatureScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onBack,
    required this.onComplete,
    this.formId,
    this.auditorRoleLabel = 'Auditor',
  });

  @override
  State<SummarySignatureScreen> createState() => _SummarySignatureScreenState();
}

class _SummarySignatureScreenState extends State<SummarySignatureScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserProfileStore _profileStore = UserProfileStore();
  final AuthStorage _authStorage = AuthStorage();

  // Site Representative fields
  bool _isSiteRepAvailable = false;
  final TextEditingController _siteRepNameController = TextEditingController();
  final FocusNode _siteRepNameFocusNode = FocusNode();
  String? _siteRepSignaturePath;

  // Auditor fields
  final TextEditingController _auditorNameController = TextEditingController();
  String? _auditorSignaturePath;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Add listener to capitalize site rep name on focus loss
    _siteRepNameFocusNode.addListener(() {
      if (!_siteRepNameFocusNode.hasFocus) {
        _capitalizeName(_siteRepNameController);
      }
    });
  }

  @override
  void dispose() {
    _siteRepNameController.dispose();
    _siteRepNameFocusNode.dispose();
    _auditorNameController.dispose();
    super.dispose();
  }

  void _capitalizeName(TextEditingController controller) {
    final text = controller.text;
    if (text.isEmpty) return;

    // Convert to title case (capitalize first letter of each word)
    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final capitalizedText = capitalizedWords.join(' ');
    if (capitalizedText != text) {
      controller.value = TextEditingValue(
        text: capitalizedText,
        selection: TextSelection.collapsed(offset: capitalizedText.length),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Prefer JWT-backed display name (portal-issued), then cached profile, then form data.
      final token = await _authStorage.readToken();
      final jwt = JwtPayload.tryParse(token);
      final jwtDisplayName = (jwt?.displayName ?? '').trim();

      if (jwtDisplayName.isNotEmpty) {
        _auditorNameController.text = jwtDisplayName;
      } else {
        final profile = await _profileStore.getProfile();
        if (profile != null && profile.displayName.isNotEmpty) {
          _auditorNameController.text = profile.displayName;
        } else if ((widget.formData['auditorName'] as String?)?.isNotEmpty ==
            true) {
          _auditorNameController.text =
              widget.formData['auditorName'] as String;
        }
      }

      // Load existing form data if any
      _isSiteRepAvailable = widget.formData['siteRepAvailable'] == true;
      _siteRepNameController.text = widget.formData['siteRepName'] ?? '';

      // Load existing signatures if available
      _siteRepSignaturePath = widget.formData['siteRepSignature'] as String?;
      _auditorSignaturePath = widget.formData['auditorSignature'] as String?;

      // Web editor: signature capture uses local file paths in the mobile app.
      // Those paths are not meaningful in a browser, so we keep whatever values
      // exist in the payload but do not attempt file IO validation.
      if (kIsWeb) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Never auto-apply a cached signature to a form that hasn't been signed.
      // This avoids showing "Signature Captured" before the user signs and
      // prevents unsigned forms from passing signature validation.
      final savedSig = (_auditorSignaturePath ?? '').trim();
      if (savedSig.isNotEmpty && !File(savedSig).existsSync()) {
        final cached = await _readCachedAuditorSignaturePath();
        if (cached != null && File(cached).existsSync()) {
          _auditorSignaturePath = cached;
        }
      }

      if (_siteRepSignaturePath != null &&
          File(_siteRepSignaturePath!).existsSync()) {
        developer.log('Site rep signature exists at: $_siteRepSignaturePath');
      }
      if (_auditorSignaturePath != null &&
          File(_auditorSignaturePath!).existsSync()) {
        developer.log('Auditor signature exists at: $_auditorSignaturePath');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      developer.log('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAndComplete() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Web editor: signature capture is file-based (mobile) and not supported.
    // Allow completion and preserve any existing signature references in the payload.
    if (kIsWeb) {
      setState(() => _isSaving = true);
      try {
        widget.onDataChanged('siteRepAvailable', _isSiteRepAvailable);
        widget.onDataChanged('siteRepName', _siteRepNameController.text.trim());
        widget.onDataChanged('auditorName', _auditorNameController.text.trim());
        if (mounted) {
          widget.onComplete();
        }
      } catch (e) {
        developer.log('Error saving (web editor): $e');
        if (mounted) {
          setState(() => _isSaving = false);
          ApmFeedback.error(context, 'Error saving: $e');
        }
      }
      return;
    }

    final existingSiteRepSig = _siteRepSignaturePath;
    final existingAuditorSig = _auditorSignaturePath;

    // Validate required signatures (either new or existing)
    if (_isSiteRepAvailable &&
        (existingSiteRepSig == null ||
            !File(existingSiteRepSig).existsSync())) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: const Text('Please capture Site Representative signature'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (existingAuditorSig == null || !File(existingAuditorSig).existsSync()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Required'),
          content: Text('Please capture ${widget.auditorRoleLabel} signature'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? siteRepSigPath = _isSiteRepAvailable
          ? _siteRepSignaturePath
          : null;
      String? auditorSigPath = _auditorSignaturePath;

      // Validate that we have required signatures (either new or existing)
      if (_isSiteRepAvailable && siteRepSigPath == null) {
        throw Exception('Site representative signature is required');
      }
      if (auditorSigPath == null) {
        throw Exception('${widget.auditorRoleLabel} signature is required');
      }

      // Save to form data
      widget.onDataChanged('siteRepAvailable', _isSiteRepAvailable);
      widget.onDataChanged('siteRepName', _siteRepNameController.text.trim());
      widget.onDataChanged('siteRepSignature', siteRepSigPath);
      widget.onDataChanged('auditorName', _auditorNameController.text.trim());
      widget.onDataChanged('auditorSignature', auditorSigPath);

      // Cache for next time (best-effort, scoped to signed-in user + tenant).
      await _writeCachedAuditorSignaturePath(auditorSigPath);

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      developer.log('Error saving signatures: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ApmFeedback.error(context, 'Error saving: $e');
      }
    }
  }

  String _signatureCacheKey({
    required String? tenantId,
    required String? email,
  }) {
    final t = (tenantId ?? 'unknown').trim();
    final e = (email ?? 'unknown').trim().toLowerCase();
    String safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'apm.sig.auditor.${safe(t)}.${safe(e)}';
  }

  Future<String?> _readCachedAuditorSignaturePath() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _authStorage.readEmail();
    final tenantId = await _authStorage.readTenantId();
    final key = _signatureCacheKey(tenantId: tenantId, email: email);
    final raw = prefs.getString(key);
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _writeCachedAuditorSignaturePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _authStorage.readEmail();
    final tenantId = await _authStorage.readTenantId();
    final key = _signatureCacheKey(tenantId: tenantId, email: email);
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Site Representative Section
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                  'Site Representative',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Is a site representative available to sign?',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ),
                                  Switch(
                                    value: _isSiteRepAvailable,
                                    onChanged: (value) {
                                      setState(() {
                                        _isSiteRepAvailable = value;
                                        if (!value) {
                                          _siteRepNameController.clear();
                                          _siteRepSignaturePath = null;
                                        }
                                      });
                                    },
                                    activeThumbColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.8),
                                    activeTrackColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                    inactiveThumbColor: Colors.grey[400],
                                    inactiveTrackColor: Colors.grey[200],
                                    trackOutlineColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                          (Set<WidgetState> states) {
                                            if (states.contains(
                                              WidgetState.selected,
                                            )) {
                                              return Colors.transparent;
                                            }
                                            return Colors.grey[300];
                                          },
                                        ),
                                  ),
                                ],
                              ),
                              if (_isSiteRepAvailable) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _siteRepNameController,
                                  focusNode: _siteRepNameFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Site Representative Name *',
                                    hintText: 'Enter full name',
                                  ),
                                  validator: (value) {
                                    if (_isSiteRepAvailable &&
                                        (value == null ||
                                            value.trim().isEmpty)) {
                                      return 'Please enter site representative name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                if (kIsWeb)
                                  const Text(
                                    'Signature capture is disabled in the web editor.',
                                  )
                                else
                                  AppSignatureCapture(
                                    label: 'Site Representative Signature *',
                                    signaturePath: _siteRepSignaturePath,
                                    filePrefix: 'site_rep_sig',
                                    onSignatureChanged: (path) {
                                      setState(() {
                                        _siteRepSignaturePath = path;
                                      });
                                    },
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Auditor Section
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                  '${widget.auditorRoleLabel} Details',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _auditorNameController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${widget.auditorRoleLabel} Name *',
                                  hintText: 'Assigned by the portal',
                                ),
                                readOnly: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '${widget.auditorRoleLabel} name is required (set in the portal)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              if (kIsWeb)
                                const Text(
                                  'Signature capture is disabled in the web editor.',
                                )
                              else
                                AppSignatureCapture(
                                  label:
                                      '${widget.auditorRoleLabel} Signature *',
                                  signaturePath: _auditorSignaturePath,
                                  filePrefix: 'auditor_sig',
                                  onSignatureChanged: (path) {
                                    setState(() {
                                      _auditorSignaturePath = path;
                                    });
                                    unawaited(
                                      _writeCachedAuditorSignaturePath(path),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
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
                    text: _isSaving ? 'Saving...' : 'Complete Report',
                    onPressed: _isSaving ? null : _saveAndComplete,
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
