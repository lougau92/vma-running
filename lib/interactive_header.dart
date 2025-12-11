import 'package:flutter/material.dart';

class InteractiveHeader extends StatelessWidget {
  const InteractiveHeader({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;

    final resolvedTextColor = enabled
        ? colorScheme.primary
        : theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface;

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: resolvedTextColor.withOpacity(enabled ? 1 : 0.7),
    );

    List<Widget> iconWidget = icon != null
        ? [Icon(icon, size: 24, color: resolvedTextColor), SizedBox(width: 6)]
        : [SizedBox.shrink()];

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(enabled ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(enabled ? 0.5 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget.isNotEmpty) ...iconWidget,
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.touch_app,
              size: 14,
              color: resolvedTextColor.withOpacity(0.9),
            ),
          ],
        ],
      ),
    );

    final child = tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: colorScheme.primary.withOpacity(0.16),
      highlightColor: Colors.transparent,
      child: child,
    );
  }
}
