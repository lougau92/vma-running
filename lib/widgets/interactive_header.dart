import 'package:flutter/material.dart';

class InteractiveHeader extends StatelessWidget {
  const InteractiveHeader({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.tooltip,
    this.compact = false,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;

    final resolvedTextColor = enabled || emphasized
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: resolvedTextColor,
    );

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: enabled ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: enabled ? 0.5 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: resolvedTextColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.visible,
              softWrap: true,
              maxLines: 2,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );

    final child = tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);

    if (!enabled) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: colorScheme.primary.withValues(alpha: 0.16),
      highlightColor: Colors.transparent,
      child: child,
    );
  }
}

enum SortDirection { none, ascending, descending }

class SortableHeader extends StatelessWidget {
  const SortableHeader({
    super.key,
    required this.label,
    this.direction = SortDirection.none,
    this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final SortDirection direction;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      SortDirection.ascending => Icons.arrow_upward_rounded,
      SortDirection.descending => Icons.arrow_downward_rounded,
      SortDirection.none => Icons.unfold_more,
    };

    return InteractiveHeader(
      label: label,
      icon: icon,
      onTap: onTap,
      tooltip: tooltip,
      compact: compact,
    );
  }
}
