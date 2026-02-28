import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';
import '../apm/forms/heat_network_assessment/hna_web_editor_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.session,
    required this.loadFuture,
  });

  final AuthSession session;
  final Future<void> loadFuture;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Web editor launch path: BSP redirects to
    //   https://<host>/flutter/#/hna/edit?ticket=<guid>
    // We keep the ticket in the fragment and pass it via a header on API calls.
    if (kIsWeb) {
      final deepLink = _tryReadEditorDeepLink();
      if (deepLink != null) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/hna-web-editor'),
            builder: (_) => HnaWebEditorScreen(
              ticket: deepLink.ticket,
              returnUrl: deepLink.returnUrl,
            ),
          ),
        );
        return;
      }
    }

    // Small delay to avoid a flash on fast loads.
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted || _hasNavigated) return;

    await widget.loadFuture;

    if (!mounted || _hasNavigated) return;

    final hasSession = widget.session.state.value != null;
    _hasNavigated = true;

    Navigator.of(context).pushReplacementNamed(hasSession ? '/home' : '/login');
  }

  _EditorDeepLink? _tryReadEditorDeepLink() {
    try {
      // 1) Hash URL strategy: /flutter/#/hna/edit?ticket=...
      final fragment = Uri.base.fragment.trim();
      if (fragment.isNotEmpty) {
        final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
        final uri = Uri.parse(normalized);
        final dl = _tryReadDeepLinkFromUri(uri);
        if (dl != null) return dl;
      }

      // 2) Path URL strategy (just in case we switch later): /flutter/hna/edit?ticket=...
      final dlFromPath = _tryReadDeepLinkFromUri(Uri.base);
      if (dlFromPath != null) return dlFromPath;

      return null;
    } catch (_) {
      return null;
    }
  }

  _EditorDeepLink? _tryReadDeepLinkFromUri(Uri uri) {
    // We treat both as equivalent deep-links.
    final path = uri.path;
    final isHnaEdit = path == '/hna/edit' || path.startsWith('/hna/edit/');
    final isWebEditor = path == '/hna-web-editor';
    if (!isHnaEdit && !isWebEditor) return null;

    final ticket = (uri.queryParameters['ticket'] ?? '').trim();
    if (!_looksLikeGuid(ticket)) return null;

    final returnUrl = (uri.queryParameters['returnUrl'] ?? '').trim();
    return _EditorDeepLink(
      ticket: ticket,
      returnUrl: returnUrl.isEmpty ? null : Uri.decodeComponent(returnUrl),
    );
  }

  bool _looksLikeGuid(String value) {
    final v = value.trim();
    if (v.length != 36) return false;

    // xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (best-effort)
    final dashOk = v[8] == '-' && v[13] == '-' && v[18] == '-' && v[23] == '-';
    if (!dashOk) return false;

    for (var i = 0; i < v.length; i++) {
      final c = v.codeUnitAt(i);
      if (c == 45) continue; // '-'
      final isDigit = c >= 48 && c <= 57;
      final isLower = c >= 97 && c <= 102;
      final isUpper = c >= 65 && c <= 70;
      if (!isDigit && !isLower && !isUpper) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorDeepLink {
  const _EditorDeepLink({required this.ticket, required this.returnUrl});

  final String ticket;
  final String? returnUrl;
}
