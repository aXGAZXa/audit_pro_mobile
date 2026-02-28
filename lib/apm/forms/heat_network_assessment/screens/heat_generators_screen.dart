import 'package:flutter/material.dart';
import '../../../components/app_info_panel.dart';
import '../../../components/form_widgets.dart';
import '../../../components/observations_list_screen.dart';
import 'phex_list_screen.dart';
import 'heat_generator_list_screen.dart';
import 'communal_control_list_screen.dart';
import 'dhw_plant_list_screen.dart';

class HeatGeneratorsScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final int? formId;

  const HeatGeneratorsScreen({
    super.key,
    required this.formData,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
    this.formId,
  });

  @override
  State<HeatGeneratorsScreen> createState() => _HeatGeneratorsScreenState();
}

class _HeatGeneratorsScreenState extends State<HeatGeneratorsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _communalPipeworkReasonController;
  late TextEditingController _communalSpaceHeatingOtherController;
  late TextEditingController _dedicatedDhwPlantUnknownReasonController;

  @override
  void initState() {
    super.initState();
    _communalPipeworkReasonController = TextEditingController(
      text: widget.formData['communalPipeworkReason'] ?? '',
    );
    _communalPipeworkReasonController.addListener(() {
      widget.onDataChanged(
        'communalPipeworkReason',
        _communalPipeworkReasonController.text,
      );
    });

    _communalSpaceHeatingOtherController = TextEditingController(
      text: widget.formData['communalSpaceHeatingOther'] ?? '',
    );
    _communalSpaceHeatingOtherController.addListener(() {
      widget.onDataChanged(
        'communalSpaceHeatingOther',
        _communalSpaceHeatingOtherController.text,
      );
    });

    _dedicatedDhwPlantUnknownReasonController = TextEditingController(
      text: widget.formData['dedicatedCommunalDhwPlantUnknownReason'] ?? '',
    );
    _dedicatedDhwPlantUnknownReasonController.addListener(() {
      widget.onDataChanged(
        'dedicatedCommunalDhwPlantUnknownReason',
        _dedicatedDhwPlantUnknownReasonController.text,
      );
    });
  }

  @override
  void dispose() {
    _communalPipeworkReasonController.dispose();
    _communalSpaceHeatingOtherController.dispose();
    _dedicatedDhwPlantUnknownReasonController.dispose();
    super.dispose();
  }

  String get _networkType =>
      widget.formData['meetsHeatNetworkDefinition'] as String? ?? '';

  void _managePhex() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhexListScreen(),
        settings: RouteSettings(arguments: {'formId': widget.formId}),
      ),
    );
  }

  void _manageGenerators() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HeatGeneratorListScreen(),
        settings: RouteSettings(arguments: {'formId': widget.formId}),
      ),
    );
  }

  void _manageCommunalControls() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CommunalControlListScreen(),
        settings: RouteSettings(arguments: {'formId': widget.formId}),
      ),
    );
  }

  void _manageDhwPlants() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DhwPlantListScreen(),
        settings: RouteSettings(arguments: {'formId': widget.formId}),
      ),
    );
  }

  Widget _buildDhwPlantSection() {
    final selection = widget.formData['dedicatedCommunalDhwPlant'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Dedicated communal DHW plant",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Is there any dedicated communal DHW plant to capture?'),
        const SizedBox(height: 8),
        Text(
          'This is equipment dedicated to producing/storing domestic hot water (e.g. calorifier/cylinder, DHW heater, electric water heater, DHW plate heat exchanger).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ...[
          (label: 'Yes', icon: Icons.check_circle_outline, color: Colors.green),
          (label: 'No', icon: Icons.cancel_outlined, color: Colors.red),
          (label: 'Unknown', icon: Icons.help_outline, color: Colors.grey),
        ].map((item) {
          return AppSelectionCard(
            title: item.label,
            subtitle: '',
            icon: item.icon,
            color: item.color,
            selected: selection == item.label,
            onTap: () {
              widget.onDataChanged('dedicatedCommunalDhwPlant', item.label);
              if (item.label != 'Unknown') {
                widget.onDataChanged(
                  'dedicatedCommunalDhwPlantUnknownReason',
                  null,
                );
                _dedicatedDhwPlantUnknownReasonController.clear();
              }
            },
          );
        }),
        if (selection == 'Unknown') ...[
          const SizedBox(height: 12),
          AppTextField(
            label: 'Please explain why',
            controller: _dedicatedDhwPlantUnknownReasonController,
            maxLines: 3,
          ),
        ],
        if (selection == 'Yes') ...[
          const SizedBox(height: 16),
          AppButton(
            text: 'Capture DHW Plant Items',
            onPressed: _manageDhwPlants,
            icon: Icons.water_drop,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'Is the communal DHW system fitted with a secondary return?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...[
            (
              label: 'Yes',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            (label: 'No', icon: Icons.cancel_outlined, color: Colors.red),
            (
              label: 'Not Required',
              icon: Icons.do_not_disturb_on_outlined,
              color: Colors.orange,
            ),
          ].map((item) {
            final currentVal = widget.formData['dhwSecondaryReturn'] as String?;
            return AppSelectionCard(
              title: item.label,
              subtitle: '',
              icon: item.icon,
              color: item.color,
              selected: currentVal == item.label,
              onTap: () {
                widget.onDataChanged('dhwSecondaryReturn', item.label);
              },
            );
          }),
        ],
      ],
    );
  }

  void _manageCommunalPipeworkObservations() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ObservationsListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': widget.formId,
            'questionReference': 'communal_pipework',
            'questionText': 'Communal Pipework Observations',
            'sectionName': 'On-Site Generation & Distribution',
          },
        ),
      ),
    );
  }

  void _manageCommunalSpaceHeatingObservations() {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ObservationsListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': widget.formId,
            'questionReference': 'communal_space_heating',
            'questionText': 'Communal Space Heating Observations',
            'sectionName': 'On-Site Generation & Distribution',
          },
        ),
      ),
    );
  }

  Widget _buildCommunalPipeworkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Communal pipework",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Is heating and DHW communal/distribution pipework:"),
        const SizedBox(height: 16),
        ...[
          (
            label: 'Fully insulated',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          (
            label: 'Part insulated',
            icon: Icons.pie_chart_outline,
            color: Colors.orange,
          ),
          (label: 'Not insulated', icon: Icons.block, color: Colors.red),
          (
            label: 'Unable to Determine',
            icon: Icons.help_outline,
            color: Colors.grey,
          ),
        ].expand((item) {
          final widgets = <Widget>[];

          widgets.add(
            AppSelectionCard(
              title: item.label,
              subtitle: '',
              icon: item.icon,
              color: item.color,
              selected:
                  widget.formData['communalPipeworkInsulation'] == item.label,
              onTap: () {
                widget.onDataChanged('communalPipeworkInsulation', item.label);
                if (item.label != 'Part insulated') {
                  widget.onDataChanged(
                    'communalPipeworkPartInsulatedCondition',
                    null,
                  );
                }
                if (item.label != 'Unable to Determine') {
                  widget.onDataChanged('communalPipeworkReason', null);
                  _communalPipeworkReasonController.clear();
                }
              },
            ),
          );

          if (item.label == 'Part insulated' &&
              widget.formData['communalPipeworkInsulation'] ==
                  'Part insulated') {
            widgets.addAll([
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 32),
                child: AppLabel(label: 'Condition', required: true),
              ),
              const SizedBox(height: 8),
              ...[
                (
                  label:
                      'Insulated within risers/roof spaces/voids visible pipework uninsulated',
                  icon: Icons.visibility_off,
                ),
                (
                  label: 'Generally insulated but sections missing',
                  icon: Icons.construction,
                ),
                (
                  label:
                      'Generally NOT insulated or insulation in very poor condition/missing',
                  icon: Icons.broken_image,
                ),
              ].map((subItem) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: AppSelectionCard(
                    title: subItem.label,
                    subtitle: '',
                    icon: subItem.icon,
                    color: Colors.blue,
                    selected: widget.formData[
                            'communalPipeworkPartInsulatedCondition'] ==
                        subItem.label,
                    onTap: () {
                      widget.onDataChanged(
                        'communalPipeworkPartInsulatedCondition',
                        subItem.label,
                      );
                    },
                  ),
                );
              }),
            ]);
          }

          return widgets;
        }),
        if (widget.formData['communalPipeworkInsulation'] ==
            'Unable to Determine') ...[
          const SizedBox(height: 16),
          AppTextField(
            label: 'Please explain why',
            controller: _communalPipeworkReasonController,
            maxLines: 3,
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          text: 'Add a communal pipework observation',
          onPressed: _manageCommunalPipeworkObservations,
          icon: Icons.add_a_photo,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildCommunalSpaceHeatingSection() {
    List<String> selectedHeating = List<String>.from(
      widget.formData['communalSpaceHeating'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Communal Space Heating",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "How are the communal spaces heated (select all that apply):",
        ),
        const SizedBox(height: 16),
        ...[
          (label: 'Radiators', icon: Icons.grid_on),
          (label: 'Underfloor Heating', icon: Icons.grid_goldenratio),
          (label: 'Blow Convectors', icon: Icons.air),
          (label: 'AC indoor units', icon: Icons.ac_unit),
          (label: 'Heating loop', icon: Icons.loop),
          (label: 'Central Air', icon: Icons.hvac),
          (label: 'Other', icon: Icons.help_outline),
        ].expand((item) {
          List<Widget> widgets = [];
          widgets.add(
            AppSelectionCard(
              title: item.label,
              subtitle: '',
              icon: item.icon,
              color: Colors.blue,
              selected: selectedHeating.contains(item.label),
              onTap: () {
                final newList = List<String>.from(selectedHeating);
                if (newList.contains(item.label)) {
                  newList.remove(item.label);
                  if (item.label == 'Radiators') {
                    widget.onDataChanged('communalRadiatorCondition', null);
                  }
                  if (item.label == 'Other') {
                    widget.onDataChanged('communalSpaceHeatingOther', null);
                    _communalSpaceHeatingOtherController.clear();
                  }
                } else {
                  newList.add(item.label);
                }
                widget.onDataChanged('communalSpaceHeating', newList);
              },
            ),
          );

          if (item.label == 'Radiators' &&
              selectedHeating.contains('Radiators')) {
            widgets.addAll([
              ...[
                'Fitted with TRVs',
                'Some are fitted with TRVs',
                'Not fitted with TRVs',
              ].map((subItem) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: AppSelectionCard(
                    title: subItem,
                    subtitle: '',
                    icon: switch (subItem) {
                      'Fitted with TRVs' => Icons.check_circle_outline,
                      'Some are fitted with TRVs' => Icons.tonality,
                      'Not fitted with TRVs' => Icons.cancel_outlined,
                      _ => Icons.circle,
                    },
                    color: Colors.indigo,
                    selected:
                        widget.formData['communalRadiatorCondition'] == subItem,
                    onTap: () {
                      widget.onDataChanged(
                        'communalRadiatorCondition',
                        subItem,
                      );
                    },
                  ),
                );
              }),
            ]);
          }
          return widgets;
        }),
        if (selectedHeating.contains('Other')) ...[
          const SizedBox(height: 16),
          AppTextField(
            label: 'Please specify other',
            controller: _communalSpaceHeatingOtherController,
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          text: 'Add a communal space heating observation',
          onPressed: _manageCommunalSpaceHeatingObservations,
          icon: Icons.add_a_photo,
          fullWidth: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDistrict = _networkType == 'District Heat Network';

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isDistrict)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "District Heat Network Interface",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Please record details of the primary heat transfer plates from the district supply to the local heat network. (NOT secondary plate heat exchangers throughout the network)",
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            text: 'Capture Plate Heat Exchangers',
                            onPressed: _managePhex,
                            icon: Icons.settings_input_component,
                            fullWidth: true,
                          ),
                          _buildCommunalSpaceHeatingSection(),
                          _buildDhwPlantSection(),
                          _buildCommunalPipeworkSection(),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Main Controls",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppInfoPanel(
                            title: 'Communal heating controls – guidance',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Record the main communal heating controls that are readily visible during a plant room or energy centre inspection.',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Capture controls that manage the overall system, such as:',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        ['BMS panels or central controllers', 'Heating timers or programmers', 'Main system thermostats or heat sensors', 'Controls used for monitoring or remote access'].map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '• ',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    item,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  text: TextSpan(
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                        ),
                                    children: const [
                                      TextSpan(
                                        text: 'Do not capture ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            'local or dwelling-level controls (e.g. TRVs, room thermostats). These are recorded later during ',
                                      ),
                                      TextSpan(
                                        text: 'dwelling inspections',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Capture Communal Controls',
                            onPressed: _manageCommunalControls,
                            icon: Icons.toggle_on,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "On-Site Generation",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Please record details of all heat generators (Boilers, ASHP, CHP, etc.) serving the network.",
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            text: 'Capture Heat Generators',
                            onPressed: _manageGenerators,
                            icon: Icons.fireplace,
                            fullWidth: true,
                          ),
                          _buildCommunalSpaceHeatingSection(),
                          _buildDhwPlantSection(),
                          _buildCommunalPipeworkSection(),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Main Controls",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppInfoPanel(
                            title: 'Communal heating controls – guidance',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Record the main communal heating controls that are readily visible during a plant room or energy centre inspection.',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Capture controls that manage the overall system, such as:',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        ['BMS panels or central controllers', 'Heating timers or programmers', 'Main system thermostats or heat sensors', 'Controls used for monitoring or remote access'].map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '• ',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    item,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  text: TextSpan(
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                        ),
                                    children: const [
                                      TextSpan(
                                        text: 'Do not capture ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            'local or dwelling-level controls (e.g. TRVs, room thermostats). These are recorded later during ',
                                      ),
                                      TextSpan(
                                        text: 'dwelling inspections',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Capture Communal Controls',
                            onPressed: _manageCommunalControls,
                            icon: Icons.toggle_on,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(text: 'Back', onPressed: widget.onBack),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(text: 'Next', onPressed: widget.onNext),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
