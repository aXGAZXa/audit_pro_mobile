import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';
import '../../../components/app_autocomplete_field.dart';
import 'feasibility_details_screen.dart';
import 'hna_observations_list_screen.dart';
import 'meter_list_screen.dart';
import '../../../services/form_validation_feedback.dart';
import '../../../services/platform/image_persistence.dart';

class AddDwellingInspectionScreen extends StatefulWidget {
  const AddDwellingInspectionScreen({super.key});

  @override
  State<AddDwellingInspectionScreen> createState() =>
      _AddDwellingInspectionScreenState();
}

class _AddDwellingInspectionScreenState
    extends State<AddDwellingInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _makeFieldKey = GlobalKey<AppAutocompleteFieldState>();
  final _modelFieldKey = GlobalKey<AppAutocompleteFieldState>();

  final ScrollController _scrollController = ScrollController();

  final _locationController = TextEditingController();
  // final _floorController = TextEditingController(); // Removed
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();

  // New State Variables
  String? _heatingType;
  List<String> _heatGeneratorTypes = []; // Changed to List
  final _heatGeneratorOtherController = TextEditingController();
  String? _heatGeneratorFuelType;
  final _heatGeneratorFuelOtherController = TextEditingController();
  String? _heatDistributionType;
  final _heatDistributionOtherController = TextEditingController();

  String? _dhwType;
  String? _dhwGeneratorType;
  final _dhwGeneratorOtherController = TextEditingController();
  String? _dhwGeneratorFuelType;
  final _dhwGeneratorFuelOtherController = TextEditingController();
  String? _dhwCommunalType;
  final _dhwCommunalOtherController = TextEditingController();
  String? _heatingMetered; // Yes/No
  String? _heatingSubMeterFeasible; // Yes/No/Further Investigation Needed
  String _heatingSubMeterFeasibilityReason = ''; // Changed to String
  List<String> _heatingSubMeterEvidenceImages = []; // Added

  String? _dhwMetered; // Yes/No
  String? _dhwSubMeterFeasible; // Yes/No/Further Investigation Needed
  String _dhwSubMeterFeasibilityReason = ''; // Changed to String
  List<String> _dhwSubMeterEvidenceImages = []; // Added

  // Tenant controls + supporting evidence (notes + photos)
  List<String> _heatingControls = [];
  final _heatingControlsOtherController = TextEditingController();
  final _heatingNotesController = TextEditingController();
  List<XFile> _heatingImages = [];

  List<String> _dhwControls = [];
  final _dhwControlsOtherController = TextEditingController();
  final _dhwNotesController = TextEditingController();
  List<XFile> _dhwImages = [];

  bool _heatingExpanded = true;
  bool _dhwExpanded = false;

  Map<String, dynamic>? _assetsJson;
  void Function(Map<String, dynamic> nextAssets)? _onAssetsChanged;

  List<Map<String, dynamic>> _observationsJson = [];
  void Function(List<Map<String, dynamic>> nextObservations)?
  _onObservationsChanged;

  Map<String, dynamic>? _existingItem;
  String? _condition;
  String? _operational; // Yes/No

  int _observationCount = 0;
  List<XFile> _images = [];
  bool _isLoading = false;

  static const List<String> _heatingControlOptions = [
    'TRVs',
    'Room thermostat',
    'Timeclock / programmer',
    'Motorized Valve',
    'None',
    'Other',
  ];

  static const List<String> _dhwControlOptions = [
    'Cylinder/Water Heater Thermostat',
    'Economy 7 Timer',
    'Programmer',
    'Motorized Valve',
    'None',
    'Other',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    _locationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _heatGeneratorOtherController.dispose();
    _heatGeneratorFuelOtherController.dispose();
    _heatDistributionOtherController.dispose();
    _dhwGeneratorOtherController.dispose();
    _dhwGeneratorFuelOtherController.dispose();
    _dhwCommunalOtherController.dispose();
    _heatingControlsOtherController.dispose();
    _heatingNotesController.dispose();
    _dhwControlsOtherController.dispose();
    _dhwNotesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsJson != null) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final assets = args['assetsJson'];
    final onAssetsChanged = args['onAssetsChanged'];
    _assetsJson = assets is Map ? Map<String, dynamic>.from(assets) : null;
    _onAssetsChanged = onAssetsChanged is Function
        ? (onAssetsChanged as void Function(Map<String, dynamic>))
        : null;

    final obs = args['observationsJson'];
    _observationsJson = obs is List
        ? obs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true)
        : <Map<String, dynamic>>[];

    final onObsChanged = args['onObservationsChanged'];
    _onObservationsChanged = onObsChanged is Function
        ? (onObsChanged as void Function(List<Map<String, dynamic>>))
        : null;

    final rawItem = args['inspection'];
    final item = rawItem is Map ? Map<String, dynamic>.from(rawItem) : null;
    if (item == null) return;

    _existingItem = item;

    _locationController.text = (item['location'] ?? '').toString();

    final heatingType = (item['heatingType'] ?? '').toString().trim();
    _heatingType = heatingType.isEmpty ? null : heatingType;

    const heatGens = [
      'Boiler',
      'ASHP',
      'AC',
      'Storage Heaters',
      'Electric Blown',
    ];
    final heatGeneratorType = (item['heatGeneratorType'] ?? '').toString();
    if (heatGeneratorType.trim().isNotEmpty) {
      final types = heatGeneratorType.split(',');
      _heatGeneratorTypes = [];
      for (var t in types) {
        final tr = t.trim();
        if (heatGens.contains(tr)) {
          _heatGeneratorTypes.add(tr);
        } else {
          _heatGeneratorTypes.add('Other');
          _heatGeneratorOtherController.text = tr; // Assumes only one Other
        }
      }
    }

    const fuels = ['Gas', 'Oil', 'LPG', 'Electric'];
    final heatFuel = (item['heatGeneratorFuelType'] ?? '').toString().trim();
    if (heatFuel.isNotEmpty) {
      if (fuels.contains(heatFuel)) {
        _heatGeneratorFuelType = heatFuel;
      } else {
        _heatGeneratorFuelType = 'Other';
        _heatGeneratorFuelOtherController.text = heatFuel;
      }
    }

    const heatDists = [
      'Direct Connection',
      'Plate Heat Exchanger',
      'HIU',
      'Unknown',
    ];
    final heatDist = (item['heatDistributionType'] ?? '').toString().trim();
    if (heatDist.isNotEmpty) {
      if (heatDists.contains(heatDist)) {
        _heatDistributionType = heatDist;
      } else {
        _heatDistributionType = 'Other';
        _heatDistributionOtherController.text = heatDist;
      }
    }

    final dhwType = (item['dhwType'] ?? '').toString().trim();
    _dhwType = dhwType.isEmpty ? null : dhwType;

    const dhwGens = ['Combi Boiler', 'DHW Heater', 'Immersian Heater'];
    final dhwGen = (item['dhwGeneratorType'] ?? '').toString().trim();
    if (dhwGen.isNotEmpty) {
      if (dhwGens.contains(dhwGen)) {
        _dhwGeneratorType = dhwGen;
      } else {
        _dhwGeneratorType = 'Other';
        _dhwGeneratorOtherController.text = dhwGen;
      }
    }

    final dhwFuel = (item['dhwGeneratorFuelType'] ?? '').toString().trim();
    if (dhwFuel.isNotEmpty) {
      if (fuels.contains(dhwFuel)) {
        _dhwGeneratorFuelType = dhwFuel;
      } else {
        _dhwGeneratorFuelType = 'Other';
        _dhwGeneratorFuelOtherController.text = dhwFuel;
      }
    }

    const dhwComs = [
      'Direct Connection',
      'Direct Connection (With Secondary Return)',
      'Unvented Cylinder',
      'Vented Cylinder',
      'HIU',
    ];
    final dhwCom = (item['dhwCommunalType'] ?? '').toString().trim();
    if (dhwCom.isNotEmpty) {
      if (dhwComs.contains(dhwCom)) {
        _dhwCommunalType = dhwCom;
      } else {
        _dhwCommunalType = 'Other';
        _dhwCommunalOtherController.text = dhwCom;
      }
    }

    final heatingMetered = (item['heatingMetered'] ?? '').toString().trim();
    _heatingMetered = heatingMetered.isEmpty ? null : heatingMetered;
    final heatingFeasible = (item['heatingSubMeterFeasible'] ?? '')
        .toString()
        .trim();
    _heatingSubMeterFeasible = heatingFeasible.isEmpty ? null : heatingFeasible;
    _heatingSubMeterFeasibilityReason =
        (item['heatingSubMeterFeasibilityReason'] ?? '').toString();
    final heatingEvidence = item['heatingSubMeterEvidenceImages'];
    _heatingSubMeterEvidenceImages = heatingEvidence is List
        ? heatingEvidence
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: true)
        : <String>[];

    final heatingControlsRaw = item['heatingControls'];
    _heatingControls = heatingControlsRaw is List
        ? heatingControlsRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: true)
        : <String>[];
    _heatingControls = _heatingControls
        .map((v) => v == 'Motorized valve' ? 'Motorized Valve' : v)
        .toList();
    _heatingControlsOtherController.text = (item['heatingControlsOther'] ?? '')
        .toString();
    _heatingNotesController.text = (item['heatingNotes'] ?? '').toString();
    final heatingImagePathsRaw = item['heatingImagePaths'];
    final heatingImagePaths = heatingImagePathsRaw is List
        ? heatingImagePathsRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: false)
        : const <String>[];
    _heatingImages = heatingImagePaths.map((p) => XFile(p)).toList();

    final dhwMetered = (item['dhwMetered'] ?? '').toString().trim();
    _dhwMetered = dhwMetered.isEmpty ? null : dhwMetered;
    final dhwFeasible = (item['dhwSubMeterFeasible'] ?? '').toString().trim();
    _dhwSubMeterFeasible = dhwFeasible.isEmpty ? null : dhwFeasible;
    _dhwSubMeterFeasibilityReason = (item['dhwSubMeterFeasibilityReason'] ?? '')
        .toString();
    final dhwEvidence = item['dhwSubMeterEvidenceImages'];
    _dhwSubMeterEvidenceImages = dhwEvidence is List
        ? dhwEvidence
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: true)
        : <String>[];

    final dhwControlsRaw = item['dhwControls'];
    _dhwControls = dhwControlsRaw is List
        ? dhwControlsRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: true)
        : <String>[];
    _dhwControls = _dhwControls.map((v) {
      switch (v) {
        case 'Timeclock / programmer':
          return 'Programmer';
        case 'Cylinder thermostat':
          return 'Cylinder/Water Heater Thermostat';
        case 'Motorized valve':
          return 'Motorized Valve';
        default:
          return v;
      }
    }).toList();

    final unknownDhwControls = _dhwControls
        .where(
          (v) => !_dhwControlOptions.contains(v) && v != 'Other' && v != 'None',
        )
        .toList();
    final savedOther = (item['dhwControlsOther'] ?? '').toString().trim();
    if (unknownDhwControls.isNotEmpty) {
      _dhwControls.removeWhere(unknownDhwControls.contains);
      if (!_dhwControls.contains('Other')) {
        _dhwControls.add('Other');
      }

      final unknownAsText = unknownDhwControls.join(', ');
      _dhwControlsOtherController.text = savedOther.isEmpty
          ? unknownAsText
          : '$savedOther, $unknownAsText';
    } else {
      _dhwControlsOtherController.text = savedOther;
    }
    _dhwNotesController.text = (item['dhwNotes'] ?? '').toString();
    final dhwImagePathsRaw = item['dhwImagePaths'];
    final dhwImagePaths = dhwImagePathsRaw is List
        ? dhwImagePathsRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: false)
        : const <String>[];
    _dhwImages = dhwImagePaths.map((p) => XFile(p)).toList();

    _makeController.text = (item['hiuMake'] ?? '').toString();
    _modelController.text = (item['hiuModel'] ?? '').toString();
    _serialNumberController.text = (item['hiuSerialNumber'] ?? '').toString();
    final cond = (item['condition'] ?? '').toString().trim();
    _condition = cond.isEmpty ? null : cond;
    final op = (item['operational'] ?? '').toString().trim();
    _operational = op.isEmpty ? null : op;
    final imgRaw = item['imagePaths'];
    final imgPaths = imgRaw is List
        ? imgRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList(growable: false)
        : const <String>[];
    _images = imgPaths.map((path) => XFile(path)).toList();

    _updateObservationCount();
  }

  void _emitAssets(Map<String, dynamic> nextAssets) {
    final onAssetsChanged = _onAssetsChanged;
    if (onAssetsChanged == null) return;
    _assetsJson = nextAssets;
    onAssetsChanged(nextAssets);
  }

  void _emitObservations(List<Map<String, dynamic>> next) {
    final onObsChanged = _onObservationsChanged;
    _observationsJson = next;
    if (onObsChanged != null) {
      onObsChanged(next);
    }
  }

  void _updateObservationCount() {
    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final ref = 'dwelling_$id';
    final count = _observationsJson.where((o) {
      final oRef = (o['questionReference'] ?? o['question_reference'] ?? '')
          .toString()
          .trim();
      return oRef == ref;
    }).length;

    if (!mounted) return;
    setState(() => _observationCount = count);
  }

  Future<void> _viewObservations() async {
    final id = (_existingItem?['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      final saved = await _saveInternal();
      if (saved == null) return;
    }

    if (!mounted) return;

    final nextId = (_existingItem?['id'] ?? '').toString().trim();
    if (nextId.isEmpty) return;

    final ref = 'dwelling_$nextId';
    final makeModel = '${_makeController.text} ${_modelController.text}'.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HnaObservationsListScreen(
          observationsJson: _observationsJson,
          onObservationsChanged: (next) {
            _emitObservations(next);
          },
          questionReference: ref,
          questionText:
              '${_locationController.text}${makeModel.isNotEmpty ? ' - $makeModel' : ''}',
          sectionName: 'Dwelling Inspections',
          assetId: nextId,
          assetType: 'Dwelling Inspection',
          assetMakeModel: makeModel.isEmpty ? null : makeModel,
        ),
      ),
    );

    _updateObservationCount();
  }

  Future<void> _saveAndClose() async {
    final saved = await _saveInternal();
    if (saved != null && mounted) {
      Navigator.pop(context, saved);
    }
  }

  IconData _getIcon(String value) {
    switch (value) {
      case 'Communal':
        return Icons.apartment;
      case 'Self Contained':
        return Icons.home;
      case 'Boiler':
      case 'Combi Boiler':
        return Icons.water_drop;
      case 'ASHP':
        return Icons.air;
      case 'AC':
        return Icons.ac_unit;
      case 'Storage Heaters':
        return Icons.battery_charging_full;
      case 'Electric Blown':
        return Icons.wind_power;
      case 'Direct Connection':
      case 'Direct Connection (With Secondary Return)':
        return Icons.lan;
      case 'Plate Heat Exchanger':
        return Icons.layers;
      case 'HIU':
        return Icons.router;
      case 'DHW Heater':
        return Icons.water;
      case 'Immersian Heater':
        return Icons.electric_bolt;
      case 'Unvented Cylinder':
        return Icons.propane_tank;
      case 'Vented Cylinder':
        return Icons.water_damage;
      case 'Gas':
        return Icons.local_fire_department;
      case 'Oil':
        return Icons.opacity;
      case 'LPG':
        return Icons.cloud;
      case 'Electric':
        return Icons.bolt;
      case 'Unknown':
        return Icons.question_mark;
      case 'Yes':
        return Icons.check_circle_outline;
      case 'No':
        return Icons.highlight_off;
      case 'TRVs':
        return Icons.tune;
      case 'Room thermostat':
        return Icons.thermostat;
      case 'Timeclock / programmer':
        return Icons.schedule;
      case 'Programmer':
        return Icons.schedule;
      case 'Economy 7 Timer':
        return Icons.bedtime;
      case 'Motorized valve':
        return Icons.settings_applications;
      case 'Motorized Valve':
        return Icons.settings_applications;
      case 'Smart thermostat / app':
        return Icons.wifi;
      case 'Cylinder thermostat':
        return Icons.thermostat_auto;
      case 'Cylinder/Water Heater Thermostat':
        return Icons.thermostat_auto;
      case 'Thermostatic mixing valve (TMV)':
        return Icons.settings;
      case 'Temperature control':
        return Icons.device_thermostat;
      case 'Boost / override':
        return Icons.flash_on;
      case 'None':
        return Icons.block;
      case 'Other':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _getColor(String value) {
    switch (value) {
      case 'Communal':
        return Colors.orange;
      case 'Self Contained':
        return Colors.blue;
      case 'Boiler':
      case 'Combi Boiler':
        return Colors.red;
      case 'ASHP':
        return Colors.cyan;
      case 'AC':
        return Colors.lightBlue;
      case 'Storage Heaters':
        return Colors.amber;
      case 'Electric Blown':
        return Colors.yellow;
      case 'Direct Connection':
      case 'Direct Connection (With Secondary Return)':
        return Colors.green;
      case 'Plate Heat Exchanger':
        return Colors.indigo;
      case 'HIU':
        return Colors.purple;
      case 'DHW Heater':
        return Colors.orange;
      case 'Immersian Heater':
        return Colors.yellow;
      case 'Unvented Cylinder':
        return Colors.brown;
      case 'Vented Cylinder':
        return Colors.lightBlue;
      case 'Gas':
        return Colors.orange;
      case 'Oil':
        return Colors.black87;
      case 'LPG':
        return Colors.blueGrey;
      case 'Electric':
        return Colors.yellow[800]!;
      case 'Unknown':
        return Colors.grey;
      case 'Yes':
        return Colors.green;
      case 'No':
        return Colors.red;
      case 'TRVs':
        return Colors.indigo;
      case 'Room thermostat':
        return Colors.deepPurple;
      case 'Timeclock / programmer':
        return Colors.blue;
      case 'Programmer':
        return Colors.blue;
      case 'Economy 7 Timer':
        return Colors.indigo;
      case 'Motorized valve':
        return Colors.teal;
      case 'Motorized Valve':
        return Colors.teal;
      case 'Smart thermostat / app':
        return Colors.cyan;
      case 'Cylinder thermostat':
        return Colors.purple;
      case 'Cylinder/Water Heater Thermostat':
        return Colors.purple;
      case 'Thermostatic mixing valve (TMV)':
        return Colors.teal;
      case 'Temperature control':
        return Colors.orange;
      case 'Boost / override':
        return Colors.amber;
      case 'None':
        return Colors.grey;
      case 'Other':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeatingMeteringBlock() {
    if (_heatingType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metering', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildSelectionSection(
          label: _heatingType == 'Communal'
              ? 'Is a heat meter fitted?'
              : 'Is the residents heating/cooling energy usage metered directly?',
          items: ['Yes', 'No'],
          selectedValue: _heatingMetered,
          onSelected: (val) => setState(() => _heatingMetered = val),
        ),
        if (_heatingType == 'Communal' && _heatingMetered == 'Yes')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddMeter('Heating Meter'),
              icon: const Icon(Icons.gas_meter_outlined),
              label: const Text('Manage Heat Meters'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        if ((_heatingType == 'Self Contained' || _heatingType == 'Communal') &&
            _heatingMetered == 'No') ...[
          const SizedBox(height: 8),
          _buildSelectionSection(
            label: _heatingType == 'Communal'
                ? 'Is fitting a meter possible without system modification?'
                : 'Would it be feasible to add a sub meter?',
            items: ['Yes', 'No', 'Further Investigation Needed'],
            selectedValue: _heatingSubMeterFeasible,
            onSelected: (val) => setState(() => _heatingSubMeterFeasible = val),
          ),
          if (_heatingSubMeterFeasible == 'No' ||
              _heatingSubMeterFeasible == 'Further Investigation Needed')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToFeasibility('Heating / Cooling'),
                icon: Icon(
                  _heatingSubMeterFeasibilityReason.isNotEmpty
                      ? Icons.check_circle
                      : Icons.edit_note,
                  color: _heatingSubMeterFeasibilityReason.isNotEmpty
                      ? Colors.green
                      : null,
                ),
                label: Text(
                  _heatingSubMeterFeasibilityReason.isNotEmpty
                      ? 'Edit Explanation & Evidence'
                      : 'Add Explanation & Evidence',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDhwMeteringBlock() {
    if (_dhwType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metering', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildSelectionSection(
          label: _dhwType == 'Communal'
              ? 'Is a heat meter fitted?'
              : 'Is the residents DHW energy usage metered directly?',
          items: ['Yes', 'No'],
          selectedValue: _dhwMetered,
          onSelected: (val) => setState(() => _dhwMetered = val),
        ),
        if (_dhwType == 'Communal' && _dhwMetered == 'Yes')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddMeter('DHW Meter'),
              icon: const Icon(Icons.gas_meter_outlined),
              label: const Text('Manage Heat Meters'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        if ((_dhwType == 'Self Contained' || _dhwType == 'Communal') &&
            _dhwMetered == 'No') ...[
          const SizedBox(height: 8),
          _buildSelectionSection(
            label: _dhwType == 'Communal'
                ? 'Is fitting a meter possible without system modification?'
                : 'Would it be feasible to add a sub meter?',
            items: ['Yes', 'No', 'Further Investigation Needed'],
            selectedValue: _dhwSubMeterFeasible,
            onSelected: (val) => setState(() => _dhwSubMeterFeasible = val),
          ),
          if (_dhwSubMeterFeasible == 'No' ||
              _dhwSubMeterFeasible == 'Further Investigation Needed')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToFeasibility('DHW'),
                icon: Icon(
                  _dhwSubMeterFeasibilityReason.isNotEmpty
                      ? Icons.check_circle
                      : Icons.edit_note,
                  color: _dhwSubMeterFeasibilityReason.isNotEmpty
                      ? Colors.green
                      : null,
                ),
                label: Text(
                  _dhwSubMeterFeasibilityReason.isNotEmpty
                      ? 'Edit Explanation & Evidence'
                      : 'Add Explanation & Evidence',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSelectionSection({
    required String label,
    required List<String> items,
    required String? selectedValue,
    required Function(String) onSelected,
    TextEditingController? otherController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...items.map((item) {
          return AppSelectionCard(
            title: item,
            subtitle: 'Select $item',
            icon: _getIcon(item),
            color: _getColor(item),
            selected: selectedValue == item,
            onTap: () => onSelected(item),
          );
        }),
        if (selectedValue == 'Other' && otherController != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: AppTextField(
              label: 'Specify $label',
              controller: otherController,
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMultiSelectionSection({
    required String label,
    required List<String> items,
    required List<String> selectedValues,
    required Function(String, bool) onSelected,
    TextEditingController? otherController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...items.map((item) {
          final isSelected = selectedValues.contains(item);
          return AppSelectionCard(
            title: item,
            subtitle: isSelected ? 'Selected' : 'Tap to select',
            icon: _getIcon(item),
            color: _getColor(item),
            selected: isSelected,
            onTap: () => onSelected(item, !isSelected),
          );
        }),
        if (selectedValues.contains('Other') && otherController != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: AppTextField(
              label: 'Specify $label',
              controller: otherController,
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<Map<String, dynamic>?> _saveInternal() async {
    if (!FormValidationFeedback.validate(
      context,
      _formKey,
      scrollController: _scrollController,
    )) {
      return null;
    }

    setState(() => _isLoading = true);

    try {
      await _locationFieldKey.currentState?.saveSuggestion();
      await _makeFieldKey.currentState?.saveSuggestion();
      await _modelFieldKey.currentState?.saveSuggestion();

      final imagePaths = await persistPickedImagePaths(
        _images,
        prefix: 'dwelling',
      );
      final heatingImagePaths = await persistPickedImagePaths(
        _heatingImages,
        prefix: 'dwelling_heating',
      );
      final dhwImagePaths = await persistPickedImagePaths(
        _dhwImages,
        prefix: 'dwelling_dhw',
      );

      String toCamelCase(String text) {
        if (text.isEmpty) return text;
        return text
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
      }

      // Helper to resolve Other values
      String? resolveValue(
        String? value,
        TextEditingController otherController,
      ) {
        if (value == 'Other') {
          return otherController.text.trim().isNotEmpty
              ? otherController.text.trim()
              : 'Other';
        }
        return value;
      }

      final heatingType = _heatingType;

      String? heatGeneratorType;
      String? heatGeneratorFuelType;
      String? heatDistributionType;

      if (heatingType == 'Self Contained') {
        final List<String> resolvedTypes = [];
        for (var t in _heatGeneratorTypes) {
          if (t == 'Other') {
            final otherVal = _heatGeneratorOtherController.text.trim();
            if (otherVal.isNotEmpty) {
              resolvedTypes.add(otherVal);
            } else {
              resolvedTypes.add('Other');
            }
          } else {
            resolvedTypes.add(t);
          }
        }
        heatGeneratorType = resolvedTypes.isEmpty
            ? null
            : resolvedTypes.join(',');

        if (_heatGeneratorTypes.contains('Boiler')) {
          heatGeneratorFuelType = resolveValue(
            _heatGeneratorFuelType,
            _heatGeneratorFuelOtherController,
          );
        }
      } else if (heatingType == 'Communal') {
        heatDistributionType = resolveValue(
          _heatDistributionType,
          _heatDistributionOtherController,
        );
      }

      final dhwType = _dhwType;
      String? dhwGeneratorType;
      String? dhwGeneratorFuelType;
      String? dhwCommunalType;

      if (dhwType == 'Self Contained') {
        dhwGeneratorType = resolveValue(
          _dhwGeneratorType,
          _dhwGeneratorOtherController,
        );
        if (_dhwGeneratorType == 'Combi Boiler' ||
            _dhwGeneratorType == 'DHW Heater') {
          dhwGeneratorFuelType = resolveValue(
            _dhwGeneratorFuelType,
            _dhwGeneratorFuelOtherController,
          );
        }
      } else if (dhwType == 'Communal') {
        dhwCommunalType = resolveValue(
          _dhwCommunalType,
          _dhwCommunalOtherController,
        );
      }

      // Check if HIU is present
      // HIU is relevant if Heat Distribution is HIU OR DHW Communal is HIU
      // relying on the Dropdown selection to match UI visibility logic
      bool hasHiu =
          (_heatDistributionType == 'HIU') || (_dhwCommunalType == 'HIU');

      final now = DateTime.now().toUtc();
      final existingId = (_existingItem?['id'] ?? '').toString().trim();
      final id = existingId.isEmpty ? const Uuid().v4() : existingId;
      final existingCreatedAt = (_existingItem?['createdAt'] ?? '')
          .toString()
          .trim();
      final createdAt = existingId.isEmpty
          ? now.toIso8601String()
          : (existingCreatedAt.isEmpty
                ? now.toIso8601String()
                : existingCreatedAt);

      final saved = <String, dynamic>{
        'id': id,
        'location': toCamelCase(_locationController.text.trim()),
        'heatingType': heatingType,
        'heatGeneratorType': heatGeneratorType,
        'heatGeneratorFuelType': heatGeneratorFuelType,
        'heatDistributionType': heatDistributionType,
        'dhwType': dhwType,
        'dhwGeneratorType': dhwGeneratorType,
        'dhwGeneratorFuelType': dhwGeneratorFuelType,
        'dhwCommunalType': dhwCommunalType,
        'heatingMetered': _heatingMetered,
        'heatingSubMeterFeasible': _heatingSubMeterFeasible,
        'heatingSubMeterFeasibilityReason': _heatingSubMeterFeasible == 'Yes'
            ? null
            : _heatingSubMeterFeasibilityReason,
        'heatingSubMeterEvidenceImages': List<String>.from(
          _heatingSubMeterEvidenceImages,
        ),
        'dhwMetered': _dhwMetered,
        'dhwSubMeterFeasible': _dhwSubMeterFeasible,
        'dhwSubMeterFeasibilityReason': _dhwSubMeterFeasible == 'Yes'
            ? null
            : _dhwSubMeterFeasibilityReason,
        'dhwSubMeterEvidenceImages': List<String>.from(
          _dhwSubMeterEvidenceImages,
        ),
        'heatingControls': List<String>.from(_heatingControls),
        'heatingControlsOther':
            _heatingControlsOtherController.text.trim().isEmpty
            ? null
            : _heatingControlsOtherController.text.trim(),
        'heatingNotes': _heatingNotesController.text.trim().isEmpty
            ? null
            : _heatingNotesController.text.trim(),
        'heatingImagePaths': heatingImagePaths,
        'dhwControls': List<String>.from(_dhwControls),
        'dhwControlsOther': _dhwControlsOtherController.text.trim().isEmpty
            ? null
            : _dhwControlsOtherController.text.trim(),
        'dhwNotes': _dhwNotesController.text.trim().isEmpty
            ? null
            : _dhwNotesController.text.trim(),
        'dhwImagePaths': dhwImagePaths,
        'hiuMake': hasHiu ? toCamelCase(_makeController.text.trim()) : null,
        'hiuModel': hasHiu
            ? (_modelController.text.trim().isNotEmpty
                  ? _modelController.text.trim()
                  : null)
            : null,
        'hiuSerialNumber': hasHiu
            ? (_serialNumberController.text.trim().isEmpty
                  ? null
                  : _serialNumberController.text.trim())
            : null,
        'condition': _condition,
        'operational': _operational,
        'imagePaths': imagePaths,
        'createdAt': createdAt,
        'updatedAt': now.toIso8601String(),
      };

      final assets = _assetsJson;
      if (assets != null) {
        final raw = assets['dwellingInspections'];
        final items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(growable: true)
            : <Map<String, dynamic>>[];

        final idx = items.indexWhere((m) => (m['id'] ?? '').toString() == id);
        if (idx >= 0) {
          items[idx] = saved;
        } else {
          items.add(saved);
        }

        final nextAssets = Map<String, dynamic>.from(assets);
        nextAssets['dwellingInspections'] = items;
        _emitAssets(nextAssets);
      }

      if (!mounted) return saved;
      setState(() {
        _existingItem = saved;
        _isLoading = false;
      });
      _updateObservationCount();

      return saved;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving inspection: $e')));
      }
      return null;
    }
  }

  void _navigateToFeasibility(String type) async {
    final isHeating = type.contains('Heating');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeasibilityDetailsScreen(),
        settings: RouteSettings(
          arguments: {
            'title': '$type Sub-meter Feasibility',
            'infoText':
                'Please explain why it is not feasible to install a sub-meter for the $type, or why further investigation is required. Add photos to provide evidence.',
            'reason': isHeating
                ? _heatingSubMeterFeasibilityReason
                : _dhwSubMeterFeasibilityReason,
            'imagePaths': isHeating
                ? _heatingSubMeterEvidenceImages
                : _dhwSubMeterEvidenceImages,
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isHeating) {
          _heatingSubMeterFeasibilityReason = result['reason'];
          _heatingSubMeterEvidenceImages = result['imagePaths'];
        } else {
          _dhwSubMeterFeasibilityReason = result['reason'];
          _dhwSubMeterEvidenceImages = result['imagePaths'];
        }
      });
    }
  }

  Future<void> _navigateToAddMeter(String meterType) async {
    final assets = _assetsJson;
    if (assets == null) return;

    // Ensure the dwelling inspection exists so we have a stable id to link meters.
    final existingId = (_existingItem?['id'] ?? '').toString().trim();
    if (existingId.isEmpty) {
      final saved = await _saveInternal();
      if (saved == null || !mounted) return;
    }

    final dwellingId = (_existingItem?['id'] ?? '').toString().trim();
    if (dwellingId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MeterListScreen(),
        settings: RouteSettings(
          arguments: {
            'formId': null,
            'networkType': meterType,
            'relatedAssetType': 'Dwelling Inspection',
            'relatedAssetId': dwellingId,
            'assetsJson': _assetsJson,
            'onAssetsChanged': (Map<String, dynamic> nextAssets) {
              _emitAssets(nextAssets);
            },
            'observationsJson': _observationsJson,
            'onObservationsChanged': (List<Map<String, dynamic>> next) {
              _emitObservations(next);
            },
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingItem != null;

    return AppScaffold(
      title: isEditing ? 'Edit Dwelling Inspection' : 'Add Dwelling Inspection',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Details
                    Text(
                      'Location Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    AppAutocompleteField(
                      key: _locationFieldKey,
                      controller: _locationController,
                      label: 'Flat Number / Location',
                      fieldName: 'location',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter location'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    Card(
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _heatingExpanded,
                          onExpansionChanged: (v) =>
                              setState(() => _heatingExpanded = v),
                          leading: Icon(
                            Icons.local_fire_department,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          trailing: Icon(
                            _heatingExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          title: const Text('Heating'),
                          collapsedBackgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSelectionSection(
                                  label: 'Heating / Cooling Type',
                                  items: ['Communal', 'Self Contained'],
                                  selectedValue: _heatingType,
                                  onSelected: (val) {
                                    setState(() {
                                      _heatingType = val;
                                      // Reset dependents
                                      _heatGeneratorTypes.clear();
                                      _heatGeneratorFuelType = null;
                                      _heatDistributionType = null;

                                      _heatingMetered = null;
                                      _heatingSubMeterFeasible = null;
                                      _heatingSubMeterFeasibilityReason = '';
                                      _heatingSubMeterEvidenceImages = [];
                                    });
                                  },
                                ),

                                if (_heatingType == 'Self Contained') ...[
                                  _buildMultiSelectionSection(
                                    label: 'Heat Generator',
                                    items: [
                                      'Boiler',
                                      'ASHP',
                                      'AC',
                                      'Storage Heaters',
                                      'Electric Blown',
                                      'Other',
                                    ],
                                    selectedValues: _heatGeneratorTypes,
                                    otherController:
                                        _heatGeneratorOtherController,
                                    onSelected: (val, isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          _heatGeneratorTypes.add(val);
                                        } else {
                                          _heatGeneratorTypes.remove(val);
                                        }

                                        if (!_heatGeneratorTypes.contains(
                                          'Boiler',
                                        )) {
                                          _heatGeneratorFuelType = null;
                                        }
                                      });
                                    },
                                  ),
                                  if (_heatGeneratorTypes.contains(
                                    'Boiler',
                                  )) ...[
                                    _buildSelectionSection(
                                      label: 'Fuel Type (for Boiler)',
                                      items: [
                                        'Gas',
                                        'Oil',
                                        'LPG',
                                        'Electric',
                                        'Other',
                                      ],
                                      selectedValue: _heatGeneratorFuelType,
                                      otherController:
                                          _heatGeneratorFuelOtherController,
                                      onSelected: (val) => setState(
                                        () => _heatGeneratorFuelType = val,
                                      ),
                                    ),
                                  ],
                                ],

                                if (_heatingType == 'Communal') ...[
                                  _buildSelectionSection(
                                    label: 'Heat Transfer Method',
                                    items: [
                                      'Direct Connection',
                                      'Plate Heat Exchanger',
                                      'HIU',
                                      'Unknown',
                                      'Other',
                                    ],
                                    selectedValue: _heatDistributionType,
                                    otherController:
                                        _heatDistributionOtherController,
                                    onSelected: (val) => setState(
                                      () => _heatDistributionType = val,
                                    ),
                                  ),
                                ],

                                _buildMultiSelectionSection(
                                  label:
                                      'Tenant Controls (select all that apply)',
                                  items: _heatingControlOptions,
                                  selectedValues: _heatingControls,
                                  otherController:
                                      _heatingControlsOtherController,
                                  onSelected: (val, isSelected) {
                                    setState(() {
                                      if (isSelected) {
                                        _heatingControls.add(val);
                                      } else {
                                        _heatingControls.remove(val);
                                      }
                                    });
                                  },
                                ),

                                _buildHeatingMeteringBlock(),
                                const SizedBox(height: 16),

                                AppTextField(
                                  label: 'Notes (optional)',
                                  controller: _heatingNotesController,
                                  maxLines: 3,
                                ),
                                AppMultiImageCapture(
                                  images: _heatingImages,
                                  onImagesChanged: (imgs) =>
                                      setState(() => _heatingImages = imgs),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _dhwExpanded,
                          onExpansionChanged: (v) =>
                              setState(() => _dhwExpanded = v),
                          leading: Icon(
                            Icons.water_drop,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          trailing: Icon(
                            _dhwExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          title: const Text('DHW'),
                          collapsedBackgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSelectionSection(
                                  label: 'DHW Type',
                                  items: ['Communal', 'Self Contained'],
                                  selectedValue: _dhwType,
                                  onSelected: (val) {
                                    setState(() {
                                      _dhwType = val;
                                      // Reset dependents
                                      _dhwGeneratorType = null;
                                      _dhwGeneratorFuelType = null;
                                      _dhwCommunalType = null;

                                      _dhwMetered = null;
                                      _dhwSubMeterFeasible = null;
                                      _dhwSubMeterFeasibilityReason = '';
                                      _dhwSubMeterEvidenceImages = [];
                                    });
                                  },
                                ),

                                if (_dhwType == 'Self Contained') ...[
                                  _buildSelectionSection(
                                    label: 'DHW Generator',
                                    items: [
                                      'Combi Boiler',
                                      'DHW Heater',
                                      'Immersian Heater',
                                      'Other',
                                    ],
                                    selectedValue: _dhwGeneratorType,
                                    otherController:
                                        _dhwGeneratorOtherController,
                                    onSelected: (val) {
                                      setState(() {
                                        _dhwGeneratorType = val;
                                        if (val != 'Combi Boiler' &&
                                            val != 'DHW Heater') {
                                          _dhwGeneratorFuelType = null;
                                        }
                                      });
                                    },
                                  ),
                                  if (_dhwGeneratorType == 'Combi Boiler' ||
                                      _dhwGeneratorType == 'DHW Heater') ...[
                                    _buildSelectionSection(
                                      label:
                                          'Fuel Type (for $_dhwGeneratorType)',
                                      items: [
                                        'Gas',
                                        'Oil',
                                        'LPG',
                                        'Electric',
                                        'Other',
                                      ],
                                      selectedValue: _dhwGeneratorFuelType,
                                      otherController:
                                          _dhwGeneratorFuelOtherController,
                                      onSelected: (val) => setState(
                                        () => _dhwGeneratorFuelType = val,
                                      ),
                                    ),
                                  ],
                                ],
                                if (_dhwType == 'Communal') ...[
                                  _buildSelectionSection(
                                    label: 'DHW Connection',
                                    items: [
                                      'Direct Connection',
                                      'Direct Connection (With Secondary Return)',
                                      'Unvented Cylinder',
                                      'Vented Cylinder',
                                      'HIU',
                                      'Other',
                                    ],
                                    selectedValue: _dhwCommunalType,
                                    otherController:
                                        _dhwCommunalOtherController,
                                    onSelected: (val) =>
                                        setState(() => _dhwCommunalType = val),
                                  ),
                                ],

                                _buildMultiSelectionSection(
                                  label:
                                      'Tenant Controls (select all that apply)',
                                  items: _dhwControlOptions,
                                  selectedValues: _dhwControls,
                                  otherController: _dhwControlsOtherController,
                                  onSelected: (val, isSelected) {
                                    setState(() {
                                      if (isSelected) {
                                        _dhwControls.add(val);
                                      } else {
                                        _dhwControls.remove(val);
                                      }
                                    });
                                  },
                                ),

                                _buildDhwMeteringBlock(),
                                const SizedBox(height: 16),

                                AppTextField(
                                  label: 'Notes (optional)',
                                  controller: _dhwNotesController,
                                  maxLines: 3,
                                ),
                                AppMultiImageCapture(
                                  images: _dhwImages,
                                  onImagesChanged: (imgs) =>
                                      setState(() => _dhwImages = imgs),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Observations
                    Text(
                      'Use observations for general dwelling notes or to record an unsafe situation.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _viewObservations,
                      icon: Icon(
                        _observationCount > 0
                            ? Icons.list_alt
                            : Icons.add_comment,
                        size: 20,
                      ),
                      label: Text(
                        _observationCount > 0
                            ? 'View Observations ($_observationCount)'
                            : 'Add Observations',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: _observationCount > 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Bottom Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[900],
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                          minimumSize: const Size(0, 48),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
