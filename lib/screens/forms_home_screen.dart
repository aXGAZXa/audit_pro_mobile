import 'package:flutter/material.dart';

import '../app/app_scaffold.dart';
import '../apm/database/database_helper.dart';
import '../apm/forms/condition_report/condition_report_definition.dart';
import '../apm/forms/condition_report/condition_report_screen.dart';
import '../apm/forms/heat_network_assessment/heat_network_assessment_definition.dart';
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
              title: 'Heat Network Assessment',
              icon: Icons.network_check,
              color: Colors.deepOrange.shade400,
              onTap: () async {
                await _openHnaFromHome(context);
              },
            ),
            const SizedBox(height: 12),
            _buildFormCard(
              context,
              title: 'Condition Report',
              icon: Icons.assignment,
              color: Colors.blue.shade400,
              onTap: () async {
                await _openCrFromHome(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCrFromHome(BuildContext context) async {
    final db = DatabaseHelper.instance;

    final drafts = await db.getFormsIndex(
      formType: kConditionReportFormType,
      statuses: const ['draft'],
    );

    if (!context.mounted) return;

    if (drafts.isNotEmpty) {
      final currentId = await db.getCurrentFormId(kConditionReportFormType);

      if (!context.mounted) return;

      final resumeId =
          (currentId != null &&
              drafts.any((d) => (d['id'] as int?) == currentId))
          ? currentId
          : (drafts.first['id'] as int);

      final choice = await showDialog<_HomeFormChoice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unfinished form found'),
            content: const Text(
              'You have an unfinished Condition Report. Do you want to start a new one or continue where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.resumeExisting),
                child: const Text('Continue'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.startNew),
                child: const Text('Start new'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (choice == null || choice == _HomeFormChoice.cancel) return;

      if (choice == _HomeFormChoice.resumeExisting) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/condition-report'),
            builder: (_) => ConditionReportScreen(formId: resumeId),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/condition-report'),
        builder: (_) => const ConditionReportScreen(forceNew: true),
      ),
    );
  }

  Future<void> _openHnaFromHome(BuildContext context) async {
    final db = DatabaseHelper.instance;

    final drafts = await db.getFormsIndex(
      formType: kHeatNetworkAssessmentFormType,
      statuses: const ['draft'],
    );

    if (!context.mounted) return;

    if (drafts.isNotEmpty) {
      final currentId = await db.getCurrentFormId(
        kHeatNetworkAssessmentFormType,
      );

      if (!context.mounted) return;

      final resumeId =
          (currentId != null &&
              drafts.any((d) => (d['id'] as int?) == currentId))
          ? currentId
          : (drafts.first['id'] as int);

      final choice = await showDialog<_HomeFormChoice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unfinished form found'),
            content: const Text(
              'You have an unfinished Heat Network Assessment. Do you want to start a new one or continue where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.resumeExisting),
                child: const Text('Continue'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HomeFormChoice.startNew),
                child: const Text('Start new'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (choice == null || choice == _HomeFormChoice.cancel) return;

      if (choice == _HomeFormChoice.resumeExisting) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/hna'),
            builder: (_) => HeatNetworkAssessmentScreen(formId: resumeId),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/hna'),
        builder: (_) => const HeatNetworkAssessmentScreen(forceNew: true),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context, {
    required String title,
    String? description,
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
                    if (description != null &&
                        description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

enum _HomeFormChoice { cancel, startNew, resumeExisting }
