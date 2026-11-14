import 'package:flutter/material.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark
          ? theme.colorScheme.secondary
          : theme.colorScheme.surface,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: isDark
          ? Colors.white70
          : theme.colorScheme.onSurface,
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
    );
  }
}
