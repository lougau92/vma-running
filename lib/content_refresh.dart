import 'dart:async' show Completer;

import 'remote_asset_loader.dart' show RemoteLoadResult;

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
