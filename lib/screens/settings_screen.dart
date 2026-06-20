import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../apm/services/apk_download_service.dart';
import '../apm/services/app_info_service.dart';
import '../apm/services/apm_portal_update_service.dart';
import '../apm/services/update_coordinator.dart';
import '../apm/services/update_state_store.dart';
import '../apm/forms/generic_skeleton/server_forms_screen.dart';
import '../apm/forms/generic_skeleton/skeleton_demo_screen.dart';
import '../app/app_scaffold.dart';
import '../auth/auth_storage.dart';
import '../auth/auth_session.dart';
import '../auth/jwt_payload.dart';
import '../auth/mobile_auth_api.dart';
import '../auth/mobile_auth_models.dart';
import '../logging/apm_feedback.dart';
import '../logging/apm_logger.dart';
import 'company_select_screen.dart';
import 'update_required_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthStorage _storage = AuthStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _requestingPlatformAccess = false;
  bool _checkingForUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) return;

    if (kIsWeb) {
      ApmFeedback.info(
        context,
        'Updates are not supported in the web version.',
        category: 'Settings',
      );
      return;
    }

    final auth = widget.session.state.value;
    if (auth == null) return;

    setState(() => _checkingForUpdates = true);

    try {
      final coordinator = UpdateCoordinator(
        updateService: ApmPortalUpdateService(session: widget.session),
        stateStore: UpdateStateStore(),
        appInfoService: AppInfoService(),
      );

      final result = await coordinator.checkForUpdates();
      if (!mounted) return;

      if (!result.checkResult.isUpdateRequired) {
        ApmFeedback.success(
          context,
          'You are up to date.',
          category: 'Settings',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UpdateRequiredScreen(
            checkResult: result.checkResult,
            apkDownloadService: ApkDownloadService(),
            continueRouteName: '/settings',
            onRecheck: () async {
              final res = await coordinator.checkForUpdates();
              return res.checkResult;
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(
        context,
        'Unable to check for updates. Please try again later.',
        category: 'Settings',
        logMessage: 'Manual update check failed: {Error}',
        logArgs: [e.toString()],
      );
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdates = false);
      }
    }
  }

  Future<void> _ensurePlatformBiometricsEnabled() async {
    final auth = widget.session.state.value;
    if (auth == null) return;

    final hasPlatformJwt = (auth.platformToken ?? '').trim().isNotEmpty;
    if (!hasPlatformJwt) return;

    if (auth.platformBiometricsEnabled) return;

    bool isSupported = false;
    bool canCheck = false;
    List<BiometricType> available = const [];

    try {
      isSupported = await _localAuth.isDeviceSupported();
    } catch (_) {
      isSupported = false;
    }

    try {
      canCheck = await _localAuth.canCheckBiometrics;
    } catch (_) {
      canCheck = false;
    }

    try {
      available = await _localAuth.getAvailableBiometrics();
    } catch (_) {
      available = const [];
    }

    ApmLogger.info(
      'Platform biometrics check (isSupported: {IsSupported}, canCheck: {CanCheck}, available: {Available})',
      args: [isSupported, canCheck, available.map((b) => b.name).toList()],
      category: 'Settings',
    );

    // On emulators, isDeviceSupported() may be flaky; canCheckBiometrics is
    // the best signal for "enrolled and ready".
    if (!canCheck || available.isEmpty) {
      await widget.session.setPlatformToken(null);
      if (!mounted) return;
      ApmFeedback.info(
        context,
        isSupported || canCheck
            ? 'No biometrics are enrolled on this device. Set a screen lock (PIN/Pattern) and add a fingerprint in Android settings to enable Platform Access.'
            : 'Biometric security is not available on this device. Platform access cannot be enabled.',
        category: 'Settings',
      );
      return;
    }

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Enable biometric security for Platform Access',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
    } catch (e) {
      await widget.session.setPlatformToken(null);
      if (!mounted) return;
      ApmFeedback.info(
        context,
        'Biometric authentication is not available. Ensure a screen lock is set and a fingerprint is enrolled, then try again.',
        category: 'Settings',
        logMessage: 'Biometric auth threw: {Error}',
        logArgs: [e.toString()],
      );
      return;
    }

    if (!mounted) return;
    if (ok) {
      await widget.session.setPlatformBiometricsEnabled(true);
      if (!mounted) return;
      ApmFeedback.success(
        context,
        'Biometric security enabled for Platform Access.',
        category: 'Settings',
      );
    } else {
      await widget.session.setPlatformToken(null);
      if (!mounted) return;
      ApmFeedback.info(
        context,
        'Biometric security was not enabled. Platform access is not granted.',
        category: 'Settings',
      );
    }
  }

  String _formatRequestedAt(BuildContext context, DateTime requestedAtUtc) {
    final local = requestedAtUtc.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState?>(
      valueListenable: widget.session.state,
      builder: (context, auth, _) {
        final jwt = JwtPayload.tryParse(auth?.token);

        final email = auth?.email ?? '';
        final name = (jwt?.displayName ?? '').trim();
        final tenantName = (auth?.tenantName ?? '').trim();
        final canAccessPlatformLogin = jwt?.canAccessPlatformLogin == true;
        final api = MobileAuthApi();

        return AppScaffold(
          title: 'Settings',
          session: widget.session,
          showScreenTitle: true,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                enabled: false,
                initialValue: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: false,
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: false,
                initialValue: tenantName,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<MobileTenantOption>>(
                future: auth == null
                    ? Future.value(const [])
                    : widget.session.readCachedTenantOptions(email: auth.email),
                builder: (context, snapshot) {
                  final options = snapshot.data ?? const <MobileTenantOption>[];
                  if (auth == null || options.length <= 1) {
                    return const SizedBox.shrink();
                  }

                  return FilledButton.tonalIcon(
                    onPressed: () async {
                      final selected = await Navigator.of(context)
                          .push<MobileTenantOption>(
                            MaterialPageRoute(
                              builder: (_) => CompanySelectScreen(
                                options: options,
                                title: 'Change company',
                              ),
                            ),
                          );
                      if (selected == null) return;

                      final currentTenantId = auth.tenantId ?? '';
                      if (selected.tenantId == currentTenantId) return;

                      ApmLogger.info(
                        'Switching company to {TenantId}',
                        args: [selected.tenantId],
                        category: 'Settings',
                      );

                      ApiResult<String> res;
                      try {
                        res = await api.switchTenant(
                          token: auth.token,
                          tenantId: selected.tenantId,
                        );
                      } catch (ex) {
                        if (!context.mounted) return;
                        ApmFeedback.error(
                          context,
                          'Unable to change company. Please check your connection.',
                          category: 'Settings',
                          logMessage: 'Switch company request threw: {Error}',
                          logArgs: [ex.toString()],
                        );
                        return;
                      }

                      if (!context.mounted) return;

                      // If the token is invalid/expired, force sign-in.
                      if (res.statusCode == 401) {
                        await widget.session.signOut();
                        if (!context.mounted) return;
                        ApmFeedback.error(
                          context,
                          'Session expired. Please sign in again.',
                          category: 'Settings',
                          logMessage: 'Switch company returned 401: {Message}',
                          logArgs: [res.message],
                        );
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (r) => false,
                        );
                        return;
                      }

                      final newToken = (res.data ?? '').trim();
                      if (!res.success || newToken.isEmpty) {
                        // Only do proactive self-heal when the server explicitly indicates
                        // access was revoked for that company (normal operation is deactivate).
                        final isAccessRevoked =
                            res.statusCode == 403 ||
                            res.message.trim().toLowerCase() ==
                                'you are not authorized for this company'
                                    .toLowerCase();

                        if (isAccessRevoked) {
                          var refreshedToken = auth.token;

                          try {
                            final refreshRes = await api.refresh(
                              token: auth.token,
                            );

                            final refreshed = (refreshRes.data ?? '').trim();
                            if (refreshRes.success && refreshed.isNotEmpty) {
                              refreshedToken = refreshed;
                            } else {
                              final msg = refreshRes.message.toLowerCase();
                              if (msg.contains('unauthorized') ||
                                  msg.contains('invalid token') ||
                                  msg.contains('user not found') ||
                                  msg.contains('inactive')) {
                                await widget.session.signOut();
                                if (!context.mounted) return;
                                ApmFeedback.error(
                                  context,
                                  'Session expired. Please sign in again.',
                                  category: 'Settings',
                                  logMessage:
                                      'Token refresh failed during access-revoked switch: {Message}',
                                  logArgs: [refreshRes.message],
                                );
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (r) => false,
                                );
                                return;
                              }
                            }
                          } catch (_) {
                            // Best-effort only.
                          }

                          try {
                            final optionsRes = await api.tenantOptions(
                              email: auth.email,
                            );
                            if (optionsRes.success) {
                              await widget.session.cacheTenantOptions(
                                email: auth.email,
                                options:
                                    optionsRes.data ??
                                    const <MobileTenantOption>[],
                              );
                            }
                          } catch (_) {
                            // Best-effort only.
                          }

                          // Force rebuild so FutureBuilder re-reads cached options.
                          await widget.session.signIn(
                            email: auth.email,
                            token: refreshedToken,
                            tenantId: auth.tenantId,
                            tenantName: auth.tenantName,
                          );
                        }

                        if (!context.mounted) return;
                        ApmFeedback.error(
                          context,
                          res.message.isEmpty
                              ? 'Unable to change company.'
                              : res.message,
                          category: 'Settings',
                          logMessage: 'Switch company failed: {Message}',
                          logArgs: [res.message],
                        );
                        return;
                      }

                      await widget.session.signIn(
                        email: auth.email,
                        token: newToken,
                        tenantId: selected.tenantId,
                        tenantName: selected.tenantName,
                      );

                      if (!context.mounted) return;
                      ApmFeedback.success(
                        context,
                        'Company changed.',
                        category: 'Settings',
                      );
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change company'),
                  );
                },
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: (auth == null || _checkingForUpdates)
                    ? null
                    : _checkForUpdates,
                icon: _checkingForUpdates
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt),
                label: Text(
                  _checkingForUpdates
                      ? 'Checking for updates...'
                      : 'Check for updates',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: auth == null
                    ? null
                    : () async {
                        ApmLogger.info('Signing out', category: 'Settings');
                        await widget.session.signOut();
                        if (!context.mounted) return;
                        ApmFeedback.info(
                          context,
                          'Signed out.',
                          category: 'Settings',
                        );
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (r) => false,
                        );
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Developer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SkeletonDemoScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Skeleton Demo (generic forms)'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ServerFormsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Server Forms (beta)'),
                ),
              ],
              if (auth != null && canAccessPlatformLogin) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Platform',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                FutureBuilder<DateTime?>(
                  future: _storage.readPlatformAccessRequestedAtUtc(
                    email: auth.email,
                  ),
                  builder: (context, snapshot) {
                    final requestedAtUtc = snapshot.data;
                    final alreadyRequested = requestedAtUtc != null;
                    final hasPlatformJwt = (auth.platformToken ?? '')
                        .trim()
                        .isNotEmpty;
                    final platformBioEnabled = auth.platformBiometricsEnabled;

                    final label = alreadyRequested
                        ? 'Requested ${_formatRequestedAt(context, requestedAtUtc)} (tap to check)'
                        : 'Request Platform Access';

                    return FilledButton.icon(
                      onPressed: _requestingPlatformAccess
                          ? null
                          : () async {
                              setState(() => _requestingPlatformAccess = true);

                              try {
                                final deviceId = await _storage
                                    .getOrCreateDeviceId();

                                if (!alreadyRequested) {
                                  ApiResult<void> res;
                                  try {
                                    res = await api.requestPlatformAccess(
                                      token: auth.token,
                                      deviceId: deviceId,
                                    );
                                  } catch (ex) {
                                    if (!context.mounted) return;
                                    ApmFeedback.error(
                                      context,
                                      'Unable to request access. Please check your connection.',
                                      category: 'Settings',
                                      logMessage:
                                          'Request platform access threw: {Error}',
                                      logArgs: [ex.toString()],
                                    );
                                    return;
                                  }

                                  if (!context.mounted) return;

                                  if (res.statusCode == 401) {
                                    await widget.session.signOut();
                                    if (!context.mounted) return;
                                    ApmFeedback.error(
                                      context,
                                      'Session expired. Please sign in again.',
                                      category: 'Settings',
                                      logMessage:
                                          'Request platform access returned 401: {Message}',
                                      logArgs: [res.message],
                                    );
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/login',
                                      (r) => false,
                                    );
                                    return;
                                  }

                                  if (!res.success) {
                                    ApmFeedback.error(
                                      context,
                                      res.message.isEmpty
                                          ? 'Request failed.'
                                          : res.message,
                                      category: 'Settings',
                                      logMessage:
                                          'Request platform access failed: {Message}',
                                      logArgs: [res.message],
                                    );
                                    return;
                                  }

                                  final nowUtc = DateTime.now().toUtc();
                                  await _storage
                                      .writePlatformAccessRequestedAtUtc(
                                        email: auth.email,
                                        requestedAtUtc: nowUtc,
                                      );

                                  if (!context.mounted) return;
                                  ApmFeedback.success(
                                    context,
                                    'Request sent. Tap again to check authorisation.',
                                    category: 'Settings',
                                  );

                                  setState(() {});
                                  return;
                                }

                                final statusRes = await api
                                    .platformAccessStatus(
                                      token: auth.token,
                                      deviceId: deviceId,
                                    );

                                if (!context.mounted) return;

                                if (statusRes.statusCode == 401) {
                                  await widget.session.signOut();
                                  if (!context.mounted) return;
                                  ApmFeedback.error(
                                    context,
                                    'Your access has been deactivated. Please sign in again.',
                                    category: 'Settings',
                                    logMessage:
                                        'Platform access status returned 401: {Message}',
                                    logArgs: [statusRes.message],
                                  );
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (r) => false,
                                  );
                                  return;
                                }

                                if (!statusRes.success ||
                                    statusRes.data == null) {
                                  ApmFeedback.error(
                                    context,
                                    statusRes.message.isEmpty
                                        ? 'Unable to check status.'
                                        : statusRes.message,
                                    category: 'Settings',
                                    logMessage:
                                        'Platform access status failed: {Message}',
                                    logArgs: [statusRes.message],
                                  );
                                  return;
                                }

                                final status = statusRes.data!.status
                                    .toLowerCase();
                                if (status == 'blocked' ||
                                    statusRes.data!.isDeviceBlocked) {
                                  await widget.session.setPlatformToken(null);
                                  if (!context.mounted) return;
                                  ApmFeedback.error(
                                    context,
                                    'This device is blocked from platform access.',
                                    category: 'Settings',
                                  );
                                  setState(() {});
                                  return;
                                }

                                if (status == 'authorised' ||
                                    statusRes.data!.isAuthorised) {
                                  final jwt =
                                      (statusRes.data!.platformJwt ?? '')
                                          .trim();
                                  if (jwt.isEmpty) {
                                    ApmFeedback.error(
                                      context,
                                      'Authorised but no token was returned.',
                                      category: 'Settings',
                                      logMessage:
                                          'Platform access status authorised but missing jwt',
                                    );
                                    return;
                                  }

                                  await widget.session.setPlatformToken(jwt);
                                  await _ensurePlatformBiometricsEnabled();

                                  final after = widget.session.state.value;
                                  final stillHasToken =
                                      (after?.platformToken ?? '')
                                          .trim()
                                          .isNotEmpty;
                                  final bioEnabled =
                                      after?.platformBiometricsEnabled == true;

                                  if (!stillHasToken || !bioEnabled) {
                                    if (!context.mounted) return;
                                    setState(() {});
                                    return;
                                  }

                                  if (!context.mounted) return;
                                  ApmFeedback.success(
                                    context,
                                    'Platform access enabled.',
                                    category: 'Settings',
                                  );
                                  setState(() {});
                                  return;
                                }

                                if (!hasPlatformJwt) {
                                  ApmFeedback.info(
                                    context,
                                    'Not authorised yet.',
                                    category: 'Settings',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(
                                    () => _requestingPlatformAccess = false,
                                  );
                                }
                              }
                            },
                      icon: Icon(
                        hasPlatformJwt
                            ? Icons.verified
                            : (alreadyRequested
                                  ? Icons.hourglass_top
                                  : Icons.how_to_reg),
                      ),
                      label: Text(
                        hasPlatformJwt
                            ? (platformBioEnabled
                                  ? 'Platform access enabled'
                                  : 'Platform access enabled (biometrics required)')
                            : label,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
