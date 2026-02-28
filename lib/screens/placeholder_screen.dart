import 'package:flutter/material.dart';

import '../app/app_scaffold.dart';
import '../auth/auth_session.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.session,
    required this.title,
  });

  final AuthSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      session: session,
      showScreenTitle: true,
      body: const Center(child: Text('Coming soon.')),
    );
  }
}
