import 'package:gtapp_mobile/gtapp_mobile.dart' hide FormState;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../logging/apm_logger.dart';
import 'app_shell_config.dart';
import '../apm/forms/generic_skeleton/generic_form_route_screen.dart';
import '../screens/delivered_screen_screen.dart';
import '../apm/components/add_asset_screen.dart';
import '../apm/components/observations_list_screen.dart';
import '../apm/forms/condition_report/screens/add_plant_room_screen.dart';
import '../apm/forms/condition_report/screens/plant_room_electrical_screen.dart';
import '../apm/forms/condition_report/screens/plant_room_gas_pipework_screen.dart';
import '../apm/forms/condition_report/screens/plant_room_general_screen.dart';
import '../apm/forms/condition_report/screens/plant_room_hydraulics_screen.dart';
import '../apm/forms/condition_report/screens/plant_room_ventilation_screen.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_screen.dart';
import '../apm/forms/heat_network_assessment/hna_repository_factory.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_requests_service.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_session_snapshot_hydrator.dart';
import '../apm/forms/services/forms_edit_sessions_service.dart';
import '../apm/forms/shared/screens/add_observation_screen.dart';
import '../apm/services/app_config_service.dart';
import '../apm/services/daily_maintenance_service.dart';
import '../screens/forms_home_screen.dart';
import '../screens/my_forms_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/submissions_screen.dart';

class AuditProApp extends StatefulWidget {
  const AuditProApp({super.key});

  @override
  State<AuditProApp> createState() => _AuditProAppState();
}

class _AuditProAppState extends State<AuditProApp> with WidgetsBindingObserver {
  final _session = AuthSession();
  late final Future<void> _loadFuture;
  late final DailyMaintenanceService _daily;

  final _editRequestsService = FormsEditRequestsService();
  final _editSessionsService = FormsEditSessionsService();
  final _hydrator = FormEditSessionSnapshotHydrator();

  // Delivered app theme (theme slice — Step 4). Seeded null → app falls back to
  // [GTAppThemeDefaults.apm] (today's look). When the user is logged in we fetch
  // the builder-authored theme and push it here; the root rebuilds via the
  // [ValueListenableBuilder] in build(), re-theming the whole app.
  final _appConfigService = AppConfigService();
  final ValueNotifier<GTAppThemeConfig?> _themeConfig =
      ValueNotifier<GTAppThemeConfig?>(null);
  // Delivered app definition (backend-driven shell: navigation + screens +
  // home). Null → the app's built-in shell.
  final ValueNotifier<AppDefinition?> _appDef =
      ValueNotifier<AppDefinition?>(null);
  bool _themeFetchInFlight = false;

  late final _navObserver = _AppNavObserver(onRouteChanged: _onRouteChanged);
  String? _topRouteName;
  bool _dailyDeferredBecauseInForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFuture = _session.load();
    _daily = DailyMaintenanceService(session: _session);

    // Re-theme reactively as auth state changes: fetch the delivered theme on
    // log-IN, clear it on log-OUT (→ baseline fallback). `_session.load()` above
    // resolves a persisted session, which fires this listener too.
    _session.state.addListener(_onAuthStateChanged);
    _onAuthStateChanged();

    // Best-effort daily maintenance (retention cleanup etc). Hard-gated so it
    // cannot run while the user is inside the form.
    Future(() => _tryRunDailyMaintenance(reason: 'startup'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.state.removeListener(_onAuthStateChanged);
    _themeConfig.dispose();
    _appDef.dispose();
    super.dispose();
  }

  /// Drives the delivered-theme fetch off the auth session. On log-OUT we clear
  /// the delivered theme so the app falls back to the baseline immediately; on
  /// log-IN we (best-effort, fail-open) fetch the builder-authored theme.
  void _onAuthStateChanged() {
    final loggedIn = (_session.state.value?.token ?? '').trim().isNotEmpty;
    if (!loggedIn) {
      _themeConfig.value = null; // baseline fallback
      _appDef.value = null; // built-in shell fallback
      return;
    }
    // Best-effort; guarded against concurrent fetches.
    Future(_fetchDeliveredConfigBestEffort);
  }

  /// Fetches the delivered [AppDefinition] ONCE and pushes both the theme and the
  /// navigation/menu to their notifiers (fail-open; never throws).
  Future<void> _fetchDeliveredConfigBestEffort() async {
    if (_themeFetchInFlight) return;
    _themeFetchInFlight = true;
    try {
      final def = await _appConfigService.fetchAppDefinition();
      if (!mounted) return;
      // Guard against a logout that raced with the fetch.
      final stillLoggedIn = (_session.state.value?.token ?? '')
          .trim()
          .isNotEmpty;
      _themeConfig.value = stillLoggedIn ? def?.theme : null;
      _appDef.value = stillLoggedIn ? def : null;
    } catch (_) {
      // fetchAppDefinition is fail-open and never throws; defensive only.
    } finally {
      _themeFetchInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryRunDailyMaintenance(reason: 'resume');
    }
  }

  void _onRouteChanged(String? routeName) {
    _topRouteName = routeName;

    // If we previously deferred a due run because the user was in-form, run it
    // as soon as they leave the form.
    if (!_isInFormRoute(_topRouteName) && _dailyDeferredBecauseInForm) {
      _dailyDeferredBecauseInForm = false;
      _tryRunDailyMaintenance(reason: 'left-form');
    }
  }

  bool _isInFormRoute(String? routeName) {
    final r = (routeName ?? '').trim();
    return r == '/hna' ||
        r.startsWith('/hna/') ||
        r == '/hna-web-editor' ||
        r.startsWith('form:');
  }

  Future<void> _tryRunDailyMaintenance({required String reason}) async {
    // Never run daily work while user is inside the form.
    if (_isInFormRoute(_topRouteName)) {
      _dailyDeferredBecauseInForm = true;
      return;
    }

    try {
      await _daily.runIfDue(
        additionalTasks: [_checkPendingEditRequestsBestEffort],
      );
    } catch (_) {
      // Best-effort by design.
    }
  }

  Future<void> _checkPendingEditRequestsBestEffort() async {
    try {
      final token = _session.state.value?.token;
      if (token == null || token.trim().isEmpty) return;

      ApmLogger.info(
        'Daily pending edit-request check',
        category: 'APM/EditRequests',
      );

      final pending = await _editRequestsService.getPending(token: token);
      if (pending.isEmpty) return;

      if (!mounted) return;

      final ctx = GTNavigator.key.currentContext;
      if (ctx == null) return;
      if (!ctx.mounted) return;

      final currentTenantId = (_session.state.value?.tenantId ?? '').trim();
      final r = pending.first;

      final sameTenant =
          currentTenantId.isNotEmpty && r.tenantId.trim() == currentTenantId;

      final requestedAt = r.requestedAtUtc;
      final requestedAtLabel = requestedAt == null
          ? ''
          : requestedAt.toLocal().toIso8601String().replaceFirst('T', ' ');

      final message = r.message.trim();
      final managerLabel = r.managerName.trim().isEmpty
          ? 'A manager'
          : r.managerName.trim();
      final tenantLabel = r.tenantName.trim().isEmpty
          ? 'your company'
          : r.tenantName.trim();

      final info = [
        '$managerLabel at $tenantLabel has requested changes to your submitted Heat Network Assessment.',
        if (requestedAtLabel.isNotEmpty) 'Requested: $requestedAtLabel',
        if (message.isNotEmpty) 'Message: $message',
        if (!sameTenant)
          'To edit this submission, please log into $tenantLabel via the Settings page.',
      ].join('\n\n');

      await showDialog<void>(
        context: ctx,
        builder: (context) {
          return AlertDialog(
            title: Text(
              pending.length == 1
                  ? 'Edit requested'
                  : 'Edit requested (${pending.length})',
            ),
            content: Text(info),
            actions: [
              if (sameTenant)
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _startEditNow(token: token, request: r);
                  },
                  child: const Text('Edit now'),
                ),
              if (!sameTenant)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    GTNavigator.key.currentState?.pushNamed('/settings');
                  },
                  child: const Text('Open Settings'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Daily pending edit-request check failed: {Error}',
        args: [e.toString()],
        category: 'APM/EditRequests',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _startEditNow({
    required String token,
    required FormPendingEditRequest request,
  }) async {
    try {
      final start = await _editSessionsService.start(
        token: token,
        editRequestId: request.editRequestId,
      );

      final snapshot = await _editSessionsService.snapshot(
        token: token,
        sessionToken: start.sessionToken,
      );

      final newFormId = await _hydrator.createDraftFromSnapshot(
        assessment: snapshot.formPayload,
        token: token,
        sessionToken: start.sessionToken,
        editRequestId: request.editRequestId,
        submissionId: snapshot.submissionId.isNotEmpty
            ? snapshot.submissionId
            : start.submissionId,
        submittedAtUtc: snapshot.submittedAtUtc,
        expiresAtUtc: start.expiresAtUtc,
      );

      final nav = GTNavigator.key.currentState;
      if (nav == null) return;

      await nav.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna'),
          builder: (_) => HeatNetworkAssessmentScreen(
            formId: newFormId,
            repo: createHnaMobileRepository(),
          ),
        ),
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Start edit from daily popup failed: {Error}',
        args: [e.toString()],
        category: 'APM/EditRequests',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme is config-driven (single-home mapper in gtapp_mobile) rather than
    // hardcoded here, and now also DELIVERED: when the builder-authored theme
    // arrives via [_themeConfig] the whole app re-themes. When no theme is
    // delivered (null), it falls back to the gtapp_mobile-owned baseline
    // ([GTAppThemeDefaults.apm]) which reproduces APM's prior look exactly
    // (Material seed Colors.blue + const GTAppTheme() defaults) — so APM stays
    // pixel-identical until a theme is authored and published.
    return ValueListenableBuilder<GTAppThemeConfig?>(
      valueListenable: _themeConfig,
      builder: (context, themeConfig, _) {
        final cfg = themeConfig ?? GTAppThemeDefaults.apm;

        return MaterialApp(
            title: 'AuditPro Mobile',
            navigatorKey: GTNavigator.key,
            theme: cfg.toMaterialThemeData(),
            darkTheme: cfg.toMaterialThemeData(Brightness.dark),
            // Follow the system brightness on the MOBILE app only. The Flutter
            // WEB build is exclusively the embedded form/web editor (same
            // main.dart, runApp(AuditProApp)); it runs inside a portal dialog
            // and must NOT pick up the operator's browser/OS dark-mode
            // preference — that turned the editor dark unexpectedly. Pin it to
            // light there. (Light is also the only authored baseline today.)
            themeMode: kIsWeb ? ThemeMode.light : ThemeMode.system,
            // GTTheme lives inside builder so it follows the brightness the
            // MaterialApp actually resolved (system light/dark), staying in
            // lockstep with the Material ThemeData. The baseline config still
            // reproduces APM's prior LIGHT look exactly; dark uses the
            // gtapp_mobile dark baseline until a dark theme is authored/delivered.
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return GTTheme(
                theme: cfg.toGTAppTheme(
                  isDark ? Brightness.dark : Brightness.light,
                ),
                // Provide the delivered app definition (nav + screens + home)
                // to the shell (AppScaffold / home / delivered-screen routes).
                child: ValueListenableBuilder<AppDefinition?>(
                  valueListenable: _appDef,
                  builder: (context, app, _) => AppShellConfig(
                    app: app,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            navigatorObservers: [_navObserver],
            routes: {
              '/': (context) =>
                  SplashScreen(session: _session, loadFuture: _loadFuture),
              '/login': (context) => LoginScreen(session: _session),
              '/home': (context) => FormsHomeScreen(session: _session),
              '/observations-list': (context) => const ObservationsListScreen(),
              '/add-observation': (context) => const AddObservationScreen(),
              '/my-forms': (context) => MyFormsScreen(session: _session),
              '/platform': (context) => PlaceholderScreen(
                session: _session,
                title: 'Platform Access',
              ),
              '/settings': (context) => SettingsScreen(session: _session),
              '/submissions': (context) => SubmissionsScreen(session: _session),
            },
            onGenerateRoute: (settings) {
              // Backend-driven menu taps encode "open form" as `form:<id>`
              // (see the navigation mapper). Resolve to the generic form screen.
              final routeName = settings.name ?? '';
              if (routeName.startsWith('form:')) {
                final formId = routeName.substring('form:'.length);
                if (formId.isNotEmpty) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => GenericFormRouteScreen(formId: formId),
                  );
                }
              }
              // Backend-driven screen navigation (`screen:<id>`).
              if (routeName.startsWith('screen:')) {
                final screenId = routeName.substring('screen:'.length);
                if (screenId.isNotEmpty) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => DeliveredScreenScreen(
                      session: _session,
                      screenId: screenId,
                    ),
                  );
                }
              }
              switch (settings.name) {
                case '/add-asset':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const AddAssetScreen(),
                  );
                case '/add-plant-room':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const AddPlantRoomScreen(),
                  );
                case '/plant-room-ventilation':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const PlantRoomVentilationScreen(),
                  );
                case '/plant-room-gas-pipework':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const PlantRoomGasPipeworkScreen(),
                  );
                case '/plant-room-general':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const PlantRoomGeneralScreen(),
                  );
                case '/plant-room-electrical':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const PlantRoomElectricalScreen(),
                  );
                case '/plant-room-hydraulics':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const PlantRoomHydraulicsScreen(),
                  );
                default:
                  return null;
              }
            },
        );
      },
    );
  }
}

class _AppNavObserver extends NavigatorObserver {
  _AppNavObserver({required this.onRouteChanged});

  final void Function(String? routeName) onRouteChanged;

  void _emit(Route<dynamic>? route) {
    onRouteChanged(route?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _emit(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _emit(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _emit(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _emit(previousRoute);
  }
}
