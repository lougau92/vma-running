import 'dart:async' show TimeoutException;

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseException, FirebaseFirestore, GetOptions, Source;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import 'firebase_content_session.dart' show FirebaseContentSession;
import 'remote_read_policy.dart' show RemoteReadPolicy;

enum RemoteLoadOrigin { network, cache, asset }

class RemoteLoadResult {
  const RemoteLoadResult({
    required this.data,
    required this.origin,
    this.error,
    this.refreshing = false,
  });

  final String data;
  final RemoteLoadOrigin origin;
  final Object? error;
  final bool refreshing;

  bool get fromCache => origin == RemoteLoadOrigin.cache;
  bool get fromAsset => origin == RemoteLoadOrigin.asset;
}

class RemoteAssetLoader {
  RemoteAssetLoader({
    FirebaseFirestore? firestore,
    FirebaseContentSession? session,
    this.policy = const RemoteReadPolicy(),
  }) : _firestore = firestore,
       _session = session ?? FirebaseContentSession();

  final FirebaseFirestore? _firestore;
  final FirebaseContentSession _session;
  final RemoteReadPolicy policy;
  final _pending = <String, Future<RemoteLoadResult>>{};
  final _memory = <String, String>{};

  /// Shows local content first, then replaces it with a fresh server read.
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) async* {
    final local = await _localText(
      documentPath,
      fieldName,
      assetPath,
      validate,
    );
    yield RemoteLoadResult(
      data: local.data,
      origin: local.origin,
      refreshing: true,
    );
    final refreshed = loadText(
      documentPath: documentPath,
      assetPath: assetPath,
      fieldName: fieldName,
      validate: validate,
    );
    // Keep the future even if it finishes while a timeout event is delivered.
    final pending = _pending[_cacheKey(documentPath, fieldName)];
    final fresh = await refreshed;
    yield fresh;
    // A timed-out SDK read can still recover when connectivity returns.
    // Stop the busy indicator at the deadline, but accept its eventual result.
    if (fresh.error is TimeoutException && pending != null) {
      try {
        yield await pending;
      } catch (_) {
        // The deadline already reported the fallback; keep displaying it.
      }
    }
  }

  /// Explicit refresh waits at most [RemoteReadPolicy.timeout] for the server.
  Future<RemoteLoadResult> loadText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) async {
    final key = _cacheKey(documentPath, fieldName);
    try {
      // Keep the underlying operation registered after a caller times out:
      // Dart timeouts do not cancel Firebase reads. A refresh reuses that work.
      final pending = _pending.putIfAbsent(
        key,
        () => _fetchAndCache(key, documentPath, fieldName, validate),
      );
      return await pending.timeout(policy.timeout);
    } catch (error) {
      _logRemoteFailure(error);
      final local = await _localText(
        documentPath,
        fieldName,
        assetPath,
        validate,
      );
      return RemoteLoadResult(
        data: local.data,
        origin: local.origin,
        error: error,
      );
    }
  }

  Future<RemoteLoadResult> _fetchAndCache(
    String key,
    String documentPath,
    String fieldName,
    void Function(String)? validate,
  ) async {
    try {
      final content = await policy.read(() async {
        await _session.ensureSignedIn();
        final snapshot = await (_firestore ?? FirebaseFirestore.instance)
            .doc(documentPath)
            .get(const GetOptions(source: Source.server));
        final content = snapshot.data()?[fieldName];
        if (content is! String) {
          throw StateError('Missing content string in Firestore document');
        }
        validate?.call(content);
        return content;
      });
      _memory[key] = content;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, content);
      } catch (_) {
        // Storage failures must not discard a successful server response.
        if (kDebugMode) debugPrint('Remote content cache write failed.');
      }
      return RemoteLoadResult(data: content, origin: RemoteLoadOrigin.network);
    } finally {
      _pending.remove(key);
    }
  }

  Future<RemoteLoadResult> _localText(
    String documentPath,
    String fieldName,
    String assetPath,
    void Function(String)? validate,
  ) async {
    final key = _cacheKey(documentPath, fieldName);
    String? cached = _memory[key];
    try {
      final prefs = await SharedPreferences.getInstance();
      cached ??= prefs.getString(key);
    } catch (_) {
      if (kDebugMode) debugPrint('Remote content cache read failed.');
    }
    if (cached != null) {
      try {
        validate?.call(cached);
        return RemoteLoadResult(data: cached, origin: RemoteLoadOrigin.cache);
      } catch (_) {
        // Old or corrupt storage must not prevent a bundled fallback.
      }
    }
    final bundled = await rootBundle.loadString(assetPath);
    validate?.call(bundled);
    return RemoteLoadResult(data: bundled, origin: RemoteLoadOrigin.asset);
  }
}

String _cacheKey(String documentPath, String fieldName) =>
    'firebase_doc_cache_${Uri.encodeComponent('$documentPath::$fieldName')}';

// Keep diagnostics local and omit messages, tokens, and document content.
void _logRemoteFailure(Object error) {
  if (!kDebugMode) return;
  var code = 'unexpected-error';
  if (error is FirebaseException &&
      RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(error.plugin) &&
      RegExp(r'^[a-z][a-z0-9-]{0,63}$').hasMatch(error.code)) {
    code = '${error.plugin}/${error.code}';
  } else if (error is StateError || error is FormatException) {
    code = 'invalid-document';
  } else if (error is TimeoutException) {
    code = 'timeout';
  }
  debugPrint('Remote content load failed ($code); using local fallback.');
}
