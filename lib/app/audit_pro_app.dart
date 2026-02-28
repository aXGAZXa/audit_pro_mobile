import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' hide FormState;

import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../logging/apm_logger.dart';
import '../apm/components/observations_list_screen.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_screen.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_requests_service.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_session_snapshot_hydrator.dart';
import '../apm/forms/heat_network_assessment/services/hna_edit_sessions_service.dart';
import '../apm/forms/shared/screens/add_observation_screen.dart';
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

  final _editRequestsService = HnaEditRequestsService();
  final _editSessionsService = HnaEditSessionsService();
  final _hydrator = HnaEditSessionSnapshotHydrator();

  late final _navObserver = _AppNavObserver(onRouteChanged: _onRouteChanged);
  String? _topRouteName;
  bool _dailyDeferredBecauseInForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFuture = _session.load();
    _daily = DailyMaintenanceService(session: _session);

    // Best-effort daily maintenance (retention cleanup etc). Hard-gated so it
    // cannot run while the user is inside the form.
    Future(() => _tryRunDailyMaintenance(reason: 'startup'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    return r == '/hna' || r.startsWith('/hna/') || r == '/hna-web-editor';
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
        category: 'HNA/EditRequests',
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
        category: 'HNA/EditRequests',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _startEditNow({
    required String token,
    required HnaPendingEditRequest request,
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
        assessment: snapshot.assessment,
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
          builder: (_) => HeatNetworkAssessmentScreen(formId: newFormId),
        ),
      );
    } catch (e, st) {
      ApmLogger.warning(
        'Start edit from daily popup failed: {Error}',
        args: [e.toString()],
        category: 'HNA/EditRequests',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    return GTTheme(
      theme: const GTAppTheme(),
      child: MaterialApp(
        title: 'AuditPro Mobile',
        navigatorKey: GTNavigator.key,
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
          ),
        ),
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
          '/platform': (context) =>
              PlaceholderScreen(session: _session, title: 'Platform Access'),
          '/settings': (context) => SettingsScreen(session: _session),
          '/submissions': (context) => SubmissionsScreen(session: _session),
        },
      ),
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
