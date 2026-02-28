import 'package:flutter/material.dart';

class AppInfoPanel extends StatefulWidget {
  final String title;
  final Widget child; // The expanded content
  final IconData icon;
  final Color? color;

  const AppInfoPanel({
    super.key,
    required this.title,
    required this.child,
    this.icon = Icons.info_outline,
    this.color,
  });

  @override
  State<AppInfoPanel> createState() => _AppInfoPanelState();
}

class _AppInfoPanelState extends State<AppInfoPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Colors.blue;
    // Using simple opacity values for broad compatibility if .withValues isn't standard in older SDKs,
    // but context suggests .withValues is used in this codebase (based on previous edits).
    // I will stick to .withValues(alpha: ...) to match existing code style I saw in `add_dwelling_inspection_screen.dart`

    return Card(
      elevation: 0,
      color: themeColor.withValues(alpha: 0.1), // Very light shade
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: themeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: themeColor,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  child: widget.child,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
