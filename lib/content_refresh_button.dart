import 'dart:async' show Completer;

import 'package:flutter/material.dart';

import 'app_localizations.dart' show AppLocalizations;
import 'remote_asset_loader.dart' show RemoteLoadResult;

class ContentRefreshButton extends StatelessWidget {
  const ContentRefreshButton({
    super.key,
    required this.refreshing,
    required this.onRefresh,
  });

  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => IconButton(
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

/// Ends pull-to-refresh at the first settled result, retaining late updates.
Future<void> refreshContent(
  Stream<RemoteLoadResult> source,
  void Function(Stream<RemoteLoadResult>) display,
) {
  final settled = Completer<void>();
  display(_trackRefresh(source, settled));
  return settled.future;
}

Stream<RemoteLoadResult> _trackRefresh(
  Stream<RemoteLoadResult> source,
  Completer<void> settled,
) async* {
  try {
    await for (final result in source) {
      if (!result.refreshing && !settled.isCompleted) settled.complete();
      yield result;
    }
  } finally {
    if (!settled.isCompleted) settled.complete();
  }
}
