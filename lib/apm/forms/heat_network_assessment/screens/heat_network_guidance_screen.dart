import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/components/form_widgets.dart';

class HeatNetworkGuidanceScreen extends StatelessWidget {
  final Function(String, bool) onTypeSelected;

  const HeatNetworkGuidanceScreen({super.key, required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heat Network Type Guidance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Select Heat Network Type',
            subtitle:
                'Click one of the options below to confirm network status',
          ),
          const SizedBox(height: 8),

          // District Heat Network
          _buildGuidanceCard(
            context,
            title: 'District Heat Network',
            subtitle: '(Heating and/or DHW)',
            icon: Icons.domain,
            color: Colors.blue,
            content: [
              'Use this if:',
              'Heat or DHW is brought onto site from an external network',
              'Heat is typically transferred via a PHEX',
              'Heat generation is not controlled by the building owner',
              'Typically operated by a third-party HNO',
              '\nExamples:',
              'City or estate heat network',
              'Energy centre serving multiple developments',
            ],
            footer: 'This is a heat network',
            footerCheck: true,
            footerText: 'Select if heat/DHW is imported from outside the site',
            onTap: () => onTypeSelected('District Heat Network', true),
          ),

          const SizedBox(height: 16),

          // Communal Heat Network
          _buildGuidanceCard(
            context,
            title: 'Communal Heat Network',
            subtitle: '(Heating and/or DHW)',
            icon: Icons.apartment,
            color: Colors.teal,
            content: [
              'Use this if:',
              'Heating and/or DHW is supplied to two or more dwellings',
              'Heat is generated on site from a shared system',
              'No external heat supplier',
              'The shared system includes:',
              'More than one heat-generating appliance, or',
              'One heat-generating appliance with heat input greater than 45 kW',
              '\nDo not use this if:',
              'A single on-site heat source serves the dwellings and',
              'The heat source has a heat input of 45 kW or less',
              '\nExamples:',
              'Multiple shared gas boilers',
              'Single central boiler > 45 kW',
              'Central ASHP serving flats',
            ],
            footer: 'This is a heat network',
            footerCheck: true,
            footerText: 'Select if the above conditions are met',
            onTap: () => onTypeSelected('Communal Heat Network', true),
          ),

          const SizedBox(height: 16),

          // In-Flat Generation
          _buildGuidanceCard(
            context,
            title: 'In-Flat Generation',
            subtitle: '(Not a heat network)',
            icon: Icons.home,
            color: Colors.grey,
            content: [
              'Use this if:',
              'Each dwelling has its own boiler or heat pump',
              'No shared heat generation or distribution',
            ],
            footer: 'This is not a heat network',
            footerCheck: true,
            footerText: 'Select if flats operate independently',
            isNegative: true,
            onTap: () => onTypeSelected('In-Flat Generation', false),
          ),

          const SizedBox(height: 16),

          // Communal areas only
          _buildGuidanceCard(
            context,
            title: 'Communal areas only',
            subtitle: '(Not a heat network)',
            icon: Icons.meeting_room,
            color: Colors.orange,
            content: [
              'Use this if:',
              'Heat is supplied only to communal spaces',
              'No heat or DHW is supplied to individual dwellings',
            ],
            footer: 'This is not a heat network',
            footerCheck: true,
            footerText: 'Select if no heat/DHW supplies dwellings',
            isNegative: true,
            onTap: () => onTypeSelected('Communal areas only', false),
          ),

          const SizedBox(height: 16),

          // Shared accommodation with no separate premises
          _buildGuidanceCard(
            context,
            title: 'Shared accommodation (no separate premises)',
            subtitle: '(Not a heat network)',
            icon: Icons.group,
            color: Colors.orange,
            content: [
              'Use this if:',
              'The building is shared accommodation (e.g. HMO / hostel style)',
              'There are no self-contained dwellings / separate premises',
              'Heat/DHW may be shared, but it does not supply multiple dwellings',
              '\nExamples:',
              'Bedrooms with shared facilities (single set of premises)',
              'Hostel-style accommodation without self-contained units',
            ],
            footer: 'This is not a heat network',
            footerCheck: true,
            footerText: 'Select if there are no separate dwellings/premises',
            isNegative: true,
            onTap: () => onTypeSelected(
              'Shared accommodation (no separate premises)',
              false,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> content,
    required String footer,
    required String footerText,
    required VoidCallback onTap,
    bool footerCheck = false,
    bool isNegative = false,
  }) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color.withValues(alpha: 0.8),
                              ),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...content.map((text) {
                    if (text.startsWith('\n')) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          text.trim(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    if (text.startsWith('Use this if:')) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: CircleAvatar(
                              radius: 2,
                              backgroundColor: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(text)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    children: [
                      if (footerCheck) ...[
                        Icon(
                          Icons.check_circle,
                          color: isNegative ? Colors.grey : Colors.green,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              footer,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              footerText,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
