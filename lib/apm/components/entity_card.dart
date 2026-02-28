import 'dart:io';
import 'package:flutter/material.dart';

/// A consistent card component for entity list items (Meters, Generators, etc)
class AppEntityCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> details;
  final List<String> imagePaths;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? accentColor;
  final bool selected;

  const AppEntityCard({
    super.key,
    required this.title,
    this.subtitle,
    this.details = const [],
    this.imagePaths = const [],
    this.actions,
    this.onTap,
    this.onDelete,
    this.accentColor,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.primaryColor;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Header Strip
            if (subtitle != null || actions != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(color: color.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    if (subtitle != null)
                      Expanded(
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (actions != null) ...actions!,
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title.isEmpty ? 'Unknown' : title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Details
                  ...details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: d,
                    ),
                  ),

                  // Images
                  if (imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imagePaths.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(imagePaths[index]),
                                  height: 72,
                                  width: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.grey[100],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEntityAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const AppEntityAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: label,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.primary,
      visualDensity: VisualDensity.compact,
    );
  }
}

class AppEntityDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? valueColor;

  const AppEntityDetail({
    super.key,
    required this.icon,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: valueColor ?? Theme.of(context).colorScheme.outline,
              fontWeight: valueColor != null
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
