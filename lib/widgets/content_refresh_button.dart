import 'package:flutter/material.dart';

import '../app_localizations.dart' show AppLocalizations;
import '../widgets/runtime_environment_host.dart' show readRuntimeEnvironment;

class ContentRefreshButton extends StatelessWidget {
  const ContentRefreshButton({
    super.key,
    required this.refreshing,
    required this.onRefresh,
  });

  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (readRuntimeEnvironment().isMobile) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: AppLocalizations.of(context)['refreshContent'],
      onPressed: refreshing ? null : onRefresh,
      icon: refreshing
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
    );
  }
}
