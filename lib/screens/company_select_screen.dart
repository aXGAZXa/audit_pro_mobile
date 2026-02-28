import 'package:flutter/material.dart';

import '../auth/mobile_auth_models.dart';

class CompanySelectScreen extends StatelessWidget {
  const CompanySelectScreen({
    super.key,
    required this.options,
    this.title = 'Select company',
    this.subtitle,
  });

  final List<MobileTenantOption> options;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
          ],
          for (final o in options) ...[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(o),
              child: Text(o.tenantName),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
