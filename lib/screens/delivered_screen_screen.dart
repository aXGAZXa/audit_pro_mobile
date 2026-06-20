import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' as gtmobile;

import '../app/app_scaffold.dart';
import '../app/app_shell_config.dart';
import '../auth/auth_session.dart';

/// Renders a backend-delivered [gtmobile.ScreenDefinition] (resolved by id from
/// the delivered [AppShellConfig]) inside the app shell. This is the target of
/// `screen:<id>` navigation actions produced by menu items and screen cards.
class DeliveredScreenScreen extends StatelessWidget {
  const DeliveredScreenScreen({
    super.key,
    required this.session,
    required this.screenId,
  });

  final AuthSession session;
  final String screenId;

  @override
  Widget build(BuildContext context) {
    final screen = AppShellConfig.of(context)?.screenById(screenId);
    if (screen == null) {
      return AppScaffold(
        title: 'Screen',
        session: session,
        body: const Center(child: Text('Screen not found.')),
      );
    }
    return AppScaffold(
      title: screen.title,
      session: session,
      body: gtmobile.GTScreenRenderer(
        screen: screen,
        onAction: (ctx, action) => Navigator.pushNamed(ctx, action),
      ),
    );
  }
}
