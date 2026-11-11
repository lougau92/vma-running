import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// App-level retries supplement the Firebase SDK's own connection handling.
class RemoteReadPolicy {
  const RemoteReadPolicy({
    this.timeout = const Duration(seconds: 12),
    this.retryDelay = const Duration(milliseconds: 500),
  });

  final Duration timeout;
  final Duration retryDelay;

  Future<T> read<T>(Future<T> Function() fetch) async {
    final elapsed = Stopwatch()..start();
    for (var attempt = 0; ; attempt++) {
      try {
        return await fetch();
      } catch (error) {
        final delay = retryDelay * (1 << attempt);
        if (attempt == 2 ||
            !_isTransient(error) ||
            elapsed.elapsed + delay >= timeout) {
          rethrow;
        }
        await Future<void>.delayed(delay);
        if (elapsed.elapsed >= timeout) rethrow;
      }
    }
  }

  bool _isTransient(Object error) =>
      error is FirebaseException &&
      const {
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'network-request-failed',
      }.contains(error.code);
}
