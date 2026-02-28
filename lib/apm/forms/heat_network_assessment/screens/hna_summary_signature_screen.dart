import 'package:flutter/material.dart';
import '../../condition_report/screens/summary_signature_screen.dart';

class HNASummarySignatureScreen extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final int? formId;

  const HNASummarySignatureScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onBack,
    required this.onComplete,
    this.formId,
  });

  @override
  Widget build(BuildContext context) {
    // Reuse the SummarySignatureScreen from condition report
    // as it contains the logic for finding summary, site rep, auditor signature, etc.
    return SummarySignatureScreen(
      formData: formData,
      onDataChanged: onDataChanged,
      onBack: onBack,
      onComplete: onComplete,
      formId: formId,
      auditorRoleLabel: 'Assessor',
    );
  }
}
