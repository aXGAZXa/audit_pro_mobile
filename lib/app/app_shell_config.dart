import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart'
    show AppDefinition, AppNavigationConfig, ScreenDefinition;

/// Carries the DELIVERED [AppDefinition] (navigation + screens + home) down the
/// widget tree so the app shell (AppScaffold / home / delivered-screen routes)
/// can render a backend-driven shell.
///
/// Null (or empty sections) means nothing was delivered → the app falls back to
/// its built-in shell (the inherit model, same as theme). Placed inside
/// MaterialApp.builder next to GTTheme so it sits above the navigator and every
/// route can read it.
class AppShellConfig extends InheritedWidget {
  final AppDefinition? app;

  const AppShellConfig({
    super.key,
    required this.app,
    required super.child,
  });

  static AppShellConfig? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellConfig>();
  }

  AppNavigationConfig? get navigation => app?.navigation;

  List<ScreenDefinition> get screens => app?.screens ?? const [];

  String? get homeScreenId => app?.homeScreenId;

  /// The delivered home/landing screen, or null when none is designated.
  ScreenDefinition? get homeScreen {
    final id = homeScreenId;
    if (id == null || id.isEmpty) return null;
    return screenById(id);
  }

  ScreenDefinition? screenById(String id) {
    for (final s in screens) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  bool updateShouldNotify(AppShellConfig oldWidget) => app != oldWidget.app;
}
