import 'package:flutter/material.dart';

class HeatNetworkAssessmentScreen extends StatelessWidget {
  const HeatNetworkAssessmentScreen({
    super.key,
    this.formId,
    this.forceNew = false,
  });

  final int? formId;
  final bool forceNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heat Network Assessment (HNA)')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'HNA is not available in the web build of Audit Pro Mobile.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
