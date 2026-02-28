import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'jwt_payload.dart';
import 'mobile_auth_api.dart';
import 'mobile_auth_models.dart';
import '../screens/company_select_screen.dart';
import '../app/app_config.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = MobileAuthApi();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSubmitting = false;
  bool _isRequestingCode = false;
  bool _codeRequested = false;

  List<MobileTenantOption> _tenantOptions = const [];
  MobileTenantOption? _selectedTenant;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.session.state.value?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  Future<void> _requestCode() async {
    if (_isRequestingCode) return;
    if (!_formKey.currentState!.validate()) return;

    if (AppConfig.mobileAuthApiKey.isEmpty) {
      ApmFeedback.error(
        context,
        'App is not configured (missing API key).',
        category: 'LoginScreen',
        logMessage: 'OTP request blocked: missing APM_MOBILE_AUTH_API_KEY',
      );
      return;
    }

    setState(() => _isRequestingCode = true);

    ApmLogger.info(
      'Requesting OTP for {Email}',
      args: [_email],
      category: 'LoginScreen',
    );

    try {
      final res = await _api.requestOtp(email: _email);
      if (!mounted) return;

      if (!res.success) {
        ApmFeedback.warning(
          context,
          res.message.isEmpty ? 'Unable to send code.' : res.message,
          category: 'LoginScreen',
          logMessage: 'OTP request failed: {Message}',
          logArgs: [res.message],
        );
        return;
      }

      setState(() => _codeRequested = true);

      ApmFeedback.success(
        context,
        'Code sent. Check your email.',
        category: 'LoginScreen',
        logMessage: 'OTP requested successfully',
      );
    } catch (e, st) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Unable to send code. Please try again.',
        category: 'LoginScreen',
        logMessage: 'OTP request failed: {Error}',
        logArgs: [e.toString()],
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _isRequestingCode = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (AppConfig.mobileAuthApiKey.isEmpty) {
      ApmFeedback.error(
        context,
        'App is not configured (missing API key).',
        category: 'LoginScreen',
        logMessage: 'OTP verify blocked: missing APM_MOBILE_AUTH_API_KEY',
      );
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ApmFeedback.warning(
        context,
        'Enter the code from your email.',
        category: 'LoginScreen',
        logMessage: 'OTP verify blocked: missing code',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    ApmLogger.info(
      'Verifying OTP for {Email} (tenant: {Tenant})',
      args: [_email, _selectedTenant?.tenantId ?? ''],
      category: 'LoginScreen',
    );

    try {
      ApiResult<String> res;
      try {
        res = await _api.verifyOtp(email: _email, code: code);
      } on ApiTenantSelectionRequired {
        final optionsRes = await _api.tenantOptions(email: _email);
        if (!mounted) return;

        if (!optionsRes.success) {
          ApmFeedback.error(
            context,
            'Unable to load company options. Please try again.',
            category: 'LoginScreen',
            logMessage: 'Tenant options load failed: {Message}',
            logArgs: [optionsRes.message],
          );
          return;
        }

        final options = optionsRes.data ?? const <MobileTenantOption>[];
        await widget.session.cacheTenantOptions(
          email: _email,
          options: options,
        );

        if (!mounted) return;
        final selected = await Navigator.of(context).push<MobileTenantOption>(
          MaterialPageRoute(
            builder: (_) => CompanySelectScreen(
              options: options,
              subtitle: 'Choose the company you are signing in for.',
            ),
          ),
        );

        if (selected == null) return;

        res = await _api.verifyOtp(
          email: _email,
          code: code,
          tenantId: selected.tenantId,
        );

        setState(() {
          _tenantOptions = options;
          _selectedTenant = selected;
        });
      }

      if (!mounted) return;

      final token = (res.data ?? '').trim();
      if (!res.success || token.isEmpty) {
        ApmFeedback.warning(
          context,
          res.message.isEmpty ? 'Sign in failed' : res.message,
          category: 'LoginScreen',
          logMessage: 'OTP verify failed: {Message}',
          logArgs: [res.message],
        );
        return;
      }

      await widget.session.signIn(
        email: _email,
        token: token,
        tenantId: await _effectiveTenantIdForToken(token),
        tenantName: await _effectiveTenantNameForToken(token),
      );

      // Optional: lock tenant if chosen.
      final tenantId = await _effectiveTenantIdForToken(token);
      if (tenantId != null && tenantId.isNotEmpty) {
        try {
          final lockRes = await _api.lockTenant(
            token: token,
            tenantId: tenantId,
          );
          if (!lockRes.success) {
            ApmLogger.warning(
              'Tenant lock failed: {Message}',
              args: [lockRes.message],
              category: 'LoginScreen',
            );
          }
        } catch (e, st) {
          ApmLogger.warning(
            'Tenant lock exception: {Error}',
            args: [e.toString()],
            category: 'LoginScreen',
            error: e,
            stackTrace: st,
          );
        }
      }

      if (!mounted) return;
      ApmFeedback.success(
        context,
        'Signed in.',
        category: 'LoginScreen',
        logMessage: 'Signed in successfully',
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiTenantSelectionRequired {
      if (!mounted) return;

      final res = await _api.tenantOptions(email: _email);
      if (!mounted) return;

      if (!res.success) {
        ApmFeedback.error(
          context,
          'Unable to load tenant options. Please try again.',
          category: 'LoginScreen',
          logMessage: 'Tenant options load failed: {Message}',
          logArgs: [res.message],
        );
        return;
      }

      final options = res.data ?? const <MobileTenantOption>[];
      setState(() {
        _tenantOptions = options;
        _selectedTenant = null;
      });

      ApmFeedback.info(
        context,
        'Select a tenant to continue.',
        category: 'LoginScreen',
        logMessage: 'Tenant selection required for OTP verify',
      );
    } catch (e, st) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Sign in failed. Please try again.',
        category: 'LoginScreen',
        logMessage: 'Sign in exception: {Error}',
        logArgs: [e.toString()],
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _effectiveTenantIdForToken(String token) async {
    final explicit = (_selectedTenant?.tenantId ?? '').trim();
    if (explicit.isNotEmpty) return explicit;

    final payload = JwtPayload.tryParse(token);
    return (payload?.tenantId ?? '').trim().isEmpty ? null : payload!.tenantId;
  }

  Future<String?> _effectiveTenantNameForToken(String token) async {
    final explicit = (_selectedTenant?.tenantName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;

    final payload = JwtPayload.tryParse(token);
    final nameFromToken = (payload?.tenantName ?? '').trim();
    if (nameFromToken.isNotEmpty) return nameFromToken;

    final tenantId = (payload?.tenantId ?? '').trim();
    if (tenantId.isEmpty) return null;

    final cached = await widget.session.readCachedTenantOptions(email: _email);
    for (final o in cached) {
      if (o.tenantId.trim() == tenantId) {
        final n = o.tenantName.trim();
        return n.isEmpty ? null : n;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your email address to request a sign-in code.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                enabled:
                    !_codeRequested && !_isSubmitting && !_isRequestingCode,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Email is required.';
                  if (!v.contains('@')) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_tenantOptions.isNotEmpty) ...[
                DropdownButtonFormField<MobileTenantOption>(
                  key: ValueKey(_tenantOptions.length),
                  initialValue: _selectedTenant,
                  decoration: const InputDecoration(labelText: 'Select tenant'),
                  items: _tenantOptions
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.tenantName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting || _isRequestingCode
                      ? null
                      : (v) => setState(() => _selectedTenant = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tenant selection is locked until you log out.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isRequestingCode ? null : _requestCode,
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(
                  _isRequestingCode ? 'Sending code...' : 'Send code',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'One-time code',
                  hintText: 'Enter the code from your email',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? 'Signing in...'
                      : (_codeRequested ? 'Verify code' : 'Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
