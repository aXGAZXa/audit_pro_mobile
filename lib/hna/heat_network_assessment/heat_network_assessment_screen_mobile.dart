import 'package:flutter/material.dart';

import '../../apm/forms/heat_network_assessment/heat_network_assessment_screen.dart'
    as ml;

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
    return ml.HeatNetworkAssessmentScreen(formId: formId, forceNew: forceNew);
  }
}
