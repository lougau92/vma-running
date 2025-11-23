import 'package:flutter/material.dart';
import 'theme.dart';

class DecoratedScaffold extends StatelessWidget {
  const DecoratedScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EnjambeeTheme.navy,
                    Color(0xFF0F142F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        color: isDark ? null : theme.scaffoldBackgroundColor,
        child: SafeArea(child: body),
      ),
    );
  }
}
