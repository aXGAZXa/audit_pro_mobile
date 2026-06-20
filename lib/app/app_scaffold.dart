import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import '../auth/auth_session.dart';
import '../auth/auth_storage.dart';
import '../auth/mobile_auth_api.dart';
import '../auth/mobile_auth_models.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';
import 'app_shell_config.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.session,
    this.actions,
    this.floatingActionButton,
    this.showScreenTitle = false,
  });

  final String title;
  final Widget body;
  final AuthSession session;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showScreenTitle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState?>(
      valueListenable: session.state,
      builder: (context, auth, _) {
        final companyName = (auth?.tenantName ?? '').trim();
        final appBarTitle = companyName.isEmpty
            ? 'Audit Pro Mobile'
            : companyName;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            appBar: AppBar(title: Text(appBarTitle), actions: actions),
            drawer: _buildDrawer(context),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showScreenTitle)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                Expanded(child: body),
              ],
            ),
            floatingActionButton: floatingActionButton,
          ),
        );
      },
    );
  }

  /// Inherit model: render the DELIVERED menu when one is published for this app,
  /// otherwise the built-in [AppDrawer] (so the app is byte-identical to today
  /// when no menu is delivered).
  Widget _buildDrawer(BuildContext context) {
    final nav = AppShellConfig.of(context)?.navigation;
    if (nav != null && nav.items.isNotEmpty) {
      return _DeliveredDrawer(session: session, navigation: nav);
    }
    return AppDrawer(session: session);
  }
}

/// Renders a backend-authored navigation drawer via the shared
/// `toGTMenuItems()` mapper, with the system items (Settings / About / Sign out)
/// always appended as a footer so essential access is never lost.
class _DeliveredDrawer extends StatelessWidget {
  const _DeliveredDrawer({required this.session, required this.navigation});

  final AuthSession session;
  final gtmobile.AppNavigationConfig navigation;

  @override
  Widget build(BuildContext context) {
    final auth = session.state.value;
    final companyName = (auth?.tenantName ?? '').trim();
    return gtmobile.GTDrawer(
      header: Text(companyName.isEmpty ? 'Audit Pro Mobile' : companyName),
      menuItems: navigation.toGTMenuItems(),
      footerItems: [
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () {
            Navigator.pop(context);
            showDialog<void>(
              context: context,
              builder: (_) => const _AboutDialog(),
            );
          },
        ),
        if (auth != null) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              Navigator.pop(context);
              ApmLogger.info('Signing out', category: 'AppDrawer');
              await session.signOut();
              if (!context.mounted) return;
              ApmFeedback.info(context, 'Signed out.', category: 'AppDrawer');
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
            },
          ),
        ],
      ],
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final auth = session.state.value;
    final companyName = (auth?.tenantName ?? '').trim();
    final hasPlatformJwt = (auth?.platformToken ?? '').trim().isNotEmpty;
    final platformBioEnabled = auth?.platformBiometricsEnabled ?? false;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName.isEmpty ? 'Audit Pro Mobile' : companyName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('My Forms'),
            subtitle: const Text('In Progress, Pending'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/my-forms');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Submissions'),
            subtitle: const Text('Completed'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/submissions');
            },
          ),
          if (hasPlatformJwt && platformBioEnabled) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Platform Access'),
              onTap: () async {
                final currentAuth = session.state.value;
                if (currentAuth == null) return;

                final connectivity = await Connectivity().checkConnectivity();
                final hasInternet = connectivity.any(
                  (r) => r != ConnectivityResult.none,
                );
                if (!hasInternet) {
                  if (!context.mounted) return;
                  ApmFeedback.info(
                    context,
                    'Internet connection required for Platform Access.',
                    category: 'Platform',
                  );
                  return;
                }

                final localAuth = LocalAuthentication();
                bool isSupported = false;
                bool canCheck = false;
                List<BiometricType> available = const [];
                try {
                  isSupported = await localAuth.isDeviceSupported();
                } catch (_) {
                  isSupported = false;
                }

                try {
                  canCheck = await localAuth.canCheckBiometrics;
                } catch (_) {
                  canCheck = false;
                }

                try {
                  available = await localAuth.getAvailableBiometrics();
                } catch (_) {
                  available = const [];
                }

                ApmLogger.info(
                  'Platform drawer biometrics check (isSupported: {IsSupported}, canCheck: {CanCheck}, available: {Available})',
                  args: [
                    isSupported,
                    canCheck,
                    available.map((b) => b.name).toList(),
                  ],
                  category: 'Platform',
                );

                if (!canCheck || available.isEmpty) {
                  await session.setPlatformToken(null);
                  if (!context.mounted) return;
                  ApmFeedback.info(
                    context,
                    isSupported || canCheck
                        ? 'No biometrics are enrolled on this device. Set a screen lock (PIN/Pattern) and add a fingerprint in Android settings to use Platform Access.'
                        : 'Biometric security is not available on this device. Platform access is not granted.',
                    category: 'Platform',
                  );
                  return;
                }

                final ok = await localAuth.authenticate(
                  localizedReason: 'Authenticate to access Platform features',
                  options: const AuthenticationOptions(
                    biometricOnly: true,
                    stickyAuth: false,
                  ),
                );
                if (!ok) return;

                final deviceId = await AuthStorage().getOrCreateDeviceId();

                final api = MobileAuthApi();
                late final ApiResult<PlatformAccessStatus> statusRes;
                try {
                  statusRes = await api.platformAccessStatus(
                    token: currentAuth.token,
                    deviceId: deviceId,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ApmFeedback.error(
                    context,
                    'Unable to verify platform status. Please check your connection.',
                    category: 'Platform',
                    logMessage: 'Platform status request threw: {Error}',
                    logArgs: [e.toString()],
                  );
                  return;
                }

                if (statusRes.statusCode == 401) {
                  await session.signOut();
                  if (!context.mounted) return;
                  ApmFeedback.error(
                    context,
                    'Session expired. Please sign in again.',
                    category: 'Platform',
                    logMessage: 'Platform status returned 401: {Message}',
                    logArgs: [statusRes.message],
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (r) => false,
                  );
                  return;
                }

                if (!statusRes.success || statusRes.data == null) {
                  if (!context.mounted) return;
                  ApmFeedback.error(
                    context,
                    statusRes.message.isEmpty
                        ? 'Unable to verify platform status.'
                        : statusRes.message,
                    category: 'Platform',
                  );
                  return;
                }

                final status = statusRes.data!.status.toLowerCase();
                if (status == 'blocked' || statusRes.data!.isDeviceBlocked) {
                  await session.setPlatformToken(null);
                  if (!context.mounted) return;
                  ApmFeedback.error(
                    context,
                    'This device is blocked for Platform Access.',
                    category: 'Platform',
                  );
                  return;
                }

                if (status != 'authorised' &&
                    statusRes.data!.isAuthorised != true) {
                  await session.setPlatformToken(null);
                  if (!context.mounted) return;
                  ApmFeedback.info(
                    context,
                    'Platform access is not authorised.',
                    category: 'Platform',
                  );
                  return;
                }

                final freshJwt = (statusRes.data!.platformJwt ?? '').trim();
                if (freshJwt.isNotEmpty) {
                  await session.setPlatformToken(freshJwt);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pushNamed(context, '/platform');
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              showDialog<void>(
                context: context,
                builder: (_) => const _AboutDialog(),
              );
            },
          ),
          if (auth != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                ApmLogger.info('Signing out', category: 'AppDrawer');
                await session.signOut();
                if (!context.mounted) return;
                ApmFeedback.info(context, 'Signed out.', category: 'AppDrawer');
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (r) => false,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About'),
      content: const Text('Audit Pro Mobile'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
