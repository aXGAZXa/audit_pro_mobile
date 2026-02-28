import 'package:flutter/material.dart';

import '../app/app_scaffold.dart';
import '../auth/auth_session.dart';
import '../hna/heat_network_assessment/heat_network_assessment_screen.dart';

class FormsHomeScreen extends StatelessWidget {
  const FormsHomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Data Capture Forms',
      session: session,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormCard(
              context,
              title: 'Heat Network Assessment (HNA)',
              description: 'Complete and submit a Heat Network Assessment.',
              icon: Icons.network_check,
              color: Colors.deepOrange.shade400,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/hna'),
                    builder: (_) => const HeatNetworkAssessmentScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
