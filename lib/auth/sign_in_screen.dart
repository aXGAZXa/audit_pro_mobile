import 'package:flutter/material.dart';

import '../screens/company_select_screen.dart';
import 'auth_session.dart';
import 'jwt_payload.dart';
import 'mobile_auth_api.dart';
import 'mobile_auth_models.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _api = MobileAuthApi();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _busy = false;
  bool _otpRequested = false;
  String _status = '';

  MobileTenantOption? _selectedCompany;

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

  Future<void> _requestOtp() async {
    if (_email.isEmpty) {
      setState(() => _status = 'Email is required');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Requesting code…';
    });

    try {
      if (!mounted) return;
      final result = await _api.requestOtp(email: _email);
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _status = result.message.isEmpty ? 'Request failed' : result.message;
        });
        return;
      }

      setState(() {
        _otpRequested = true;
        _status = result.message.isEmpty ? 'Code sent' : result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Request error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_email.isEmpty) {
      setState(() => _status = 'Email is required');
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _status = 'Code is required');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Verifying…';
    });

    try {
      ApiResult<String> result;

      try {
        result = await _api.verifyOtp(email: _email, code: code);
      } on ApiTenantSelectionRequired {
        final optionsResult = await _api.tenantOptions(email: _email);
        if (!mounted) return;

        final options = optionsResult.data ?? const <MobileTenantOption>[];
        if (options.isEmpty) {
          setState(() {
            _status = 'No companies available for this email';
          });
          return;
        }

        final navigator = Navigator.of(context);

        await widget.session.cacheTenantOptions(
          email: _email,
          options: options,
        );

        if (!mounted) return;

        final selected = await navigator.push<MobileTenantOption>(
          MaterialPageRoute(
            builder: (_) => CompanySelectScreen(
              options: options,
              subtitle: 'Choose the company you are signing in for.',
            ),
          ),
        );

        if (selected == null) {
          setState(() => _status = 'Company selection cancelled');
          return;
        }

        setState(() => _selectedCompany = selected);

        result = await _api.verifyOtp(
          email: _email,
          code: code,
          tenantId: selected.tenantId,
        );
      }

      if (!mounted) return;
      final token = (result.data ?? '').trim();

      if (!result.success || token.isEmpty) {
        setState(() {
          _status = result.message.isEmpty ? 'Sign-in failed' : result.message;
        });
        return;
      }

      await widget.session.signIn(
        email: _email,
        token: token,
        tenantId: await _effectiveTenantIdForToken(token),
        tenantName: await _effectiveTenantNameForToken(token),
      );
      if (!mounted) return;

      final tenantId = await _effectiveTenantIdForToken(token);
      if (tenantId != null && tenantId.isNotEmpty) {
        await _api.lockTenant(token: token, tenantId: tenantId);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Verify error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<String?> _effectiveTenantIdForToken(String token) async {
    final explicit = (_selectedCompany?.tenantId ?? '').trim();
    if (explicit.isNotEmpty) return explicit;

    final payload = JwtPayload.tryParse(token);
    final inferred = (payload?.tenantId ?? '').trim();
    return inferred.isEmpty ? null : inferred;
  }

  Future<String?> _effectiveTenantNameForToken(String token) async {
    final explicit = (_selectedCompany?.tenantName ?? '').trim();
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
    final canSubmit = !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              enabled: !_busy && !_otpRequested,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'name@company.com',
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedCompany != null) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Company'),
                child: Text(_selectedCompany!.tenantName),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton(
              onPressed: canSubmit ? _requestOtp : null,
              child: Text(_otpRequested ? 'Resend code' : 'Send code'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _codeController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'One-time code',
                hintText: '123456',
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: canSubmit ? _verifyOtp : null,
              child: const Text('Verify & sign in'),
            ),
            const SizedBox(height: 12),

            Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
