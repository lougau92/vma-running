import 'dart:async' show Completer, StreamIterator, TimeoutException;

import 'package:cloud_firestore/cloud_firestore.dart'
    show
        DocumentReference,
        DocumentSnapshot,
        FirebaseException,
        FirebaseFirestore,
        GetOptions,
        Source;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:vma_running/firebase_content_session.dart'
    show FirebaseContentSession;
import 'package:vma_running/remote_asset_loader.dart'
    show RemoteAssetLoader, RemoteLoadOrigin;
import 'package:vma_running/remote_read_policy.dart' show RemoteReadPolicy;

const _path = 'app_documents/training_plan';
const _asset = 'assets/training_plans/training_example.json';
final _cacheKey =
    'firebase_doc_cache_${Uri.encodeComponent('$_path::content')}';

class _Session extends FirebaseContentSession {
  @override
  Future<void> ensureSignedIn() async {}
}

// Offline SDK boundary double; production code uses Firebase snapshots.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

// Offline SDK boundary double; avoids a database/emulator in policy tests.
// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.store);
  final _Store store;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    return _Snapshot(await store.fetch(++store.reads));
  }
}

class _Store extends Fake implements FirebaseFirestore {
  _Store(this.fetch);
  final Future<Map<String, dynamic>?> Function(int attempt) fetch;
  int reads = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    expect(path, _path);
    return _Reference(this);
  }
}

RemoteAssetLoader _loader(
  _Store store, {
  Duration timeout = const Duration(seconds: 1),
}) => RemoteAssetLoader(
  firestore: store,
  session: _Session(),
  policy: RemoteReadPolicy(timeout: timeout, retryDelay: Duration.zero),
);

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({_cacheKey: 'saved plan'}),
  );

  test(
    'shows saved content before a slow server read and then replaces it',
    () async {
      final remote = Completer<Map<String, dynamic>>();
      final store = _Store((_) => remote.future);
      final results = StreamIterator(
        _loader(store).watchText(documentPath: _path, assetPath: _asset),
      );
      expect(await results.moveNext(), isTrue);
      expect(results.current.data, 'saved plan');
      expect(results.current.origin, RemoteLoadOrigin.cache);
      expect(results.current.refreshing, isTrue);
      final next = results.moveNext();
      remote.complete({'content': 'fresh plan'});
      expect(await next, isTrue);
      expect(results.current.data, 'fresh plan');
      expect(results.current.origin, RemoteLoadOrigin.network);
      expect(results.current.refreshing, isFalse);
      expect(await results.moveNext(), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(_cacheKey),
        'fresh plan',
      );
    },
  );

  test(
    'first offline launch shows bundled content and stops after three transient failures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = _Store(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      final values = await _loader(
        store,
      ).watchText(documentPath: _path, assetPath: _asset).toList();
      expect(values.first.origin, RemoteLoadOrigin.asset);
      expect(values.first.data, contains('groups'));
      expect(values.first.refreshing, isTrue);
      expect(values.last.data, values.first.data);
      expect(values.last.refreshing, isFalse);
      expect(values.last.error, isA<FirebaseException>());
      expect(store.reads, 3);
    },
  );

  test(
    'a transient failure retries and saves the successful response',
    () async {
      final store = _Store((attempt) async {
        if (attempt < 3) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return {'content': 'recovered plan'};
      });
      final result = await _loader(
        store,
      ).loadText(documentPath: _path, assetPath: _asset);
      expect(result.origin, RemoteLoadOrigin.network);
      expect(result.data, 'recovered plan');
      expect(store.reads, 3);
    },
  );

  test(
    'permission failures are not retried and preserve the saved plan',
    () async {
      final store = _Store(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      final result = await _loader(
        store,
      ).loadText(documentPath: _path, assetPath: _asset);
      expect(result.data, 'saved plan');
      expect(result.origin, RemoteLoadOrigin.cache);
      expect(store.reads, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(_cacheKey),
        'saved plan',
      );
    },
  );

  test('missing document content is not retried or cached', () async {
    final store = _Store((_) async => null);
    final result = await _loader(
      store,
    ).loadText(documentPath: _path, assetPath: _asset);
    expect(result.error, isA<StateError>());
    expect(result.data, 'saved plan');
    expect(store.reads, 1);
  });

  test('a response completing during timeout delivery is not lost', () async {
    final remote = Completer<Map<String, dynamic>>();
    final store = _Store((_) => remote.future);
    final loader = _loader(store, timeout: const Duration(milliseconds: 20));
    final results = StreamIterator(
      loader.watchText(documentPath: _path, assetPath: _asset),
    );
    expect(await results.moveNext(), isTrue);
    expect(await results.moveNext(), isTrue);
    expect(results.current.error, isA<TimeoutException>());
    remote.complete({'content': 'late plan'});
    await _turn();
    expect(await results.moveNext(), isTrue);
    expect(results.current.data, 'late plan');
    expect(await results.moveNext(), isFalse);
  });

  test(
    'a malformed remote payload cannot overwrite the last good cache',
    () async {
      final store = _Store((_) async => {'content': 'malformed'});
      final result = await _loader(store).loadText(
        documentPath: _path,
        assetPath: _asset,
        validate: (text) {
          if (text == 'malformed') throw const FormatException('invalid plan');
        },
      );
      expect(result.data, 'saved plan');
      expect(result.error, isA<FormatException>());
      expect(store.reads, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(_cacheKey),
        'saved plan',
      );
    },
  );

  test('concurrent refreshes share one read', () async {
    final remote = Completer<Map<String, dynamic>>();
    final store = _Store((_) => remote.future);
    final loader = _loader(store);
    final first = loader.loadText(documentPath: _path, assetPath: _asset);
    final second = loader.loadText(documentPath: _path, assetPath: _asset);
    await _turn();
    expect(store.reads, 1);
    remote.complete({'content': 'fresh plan'});
    expect((await first).data, 'fresh plan');
    expect((await second).data, 'fresh plan');
  });

  test(
    'a timeout stops the busy state but a late read updates the stream',
    () async {
      final remote = Completer<Map<String, dynamic>>();
      final store = _Store((_) => remote.future);
      final loader = _loader(store, timeout: const Duration(milliseconds: 20));
      final results = StreamIterator(
        loader.watchText(documentPath: _path, assetPath: _asset),
      );
      expect(await results.moveNext(), isTrue);
      expect(await results.moveNext(), isTrue);
      expect(results.current.data, 'saved plan');
      expect(results.current.error, isA<TimeoutException>());
      expect(results.current.refreshing, isFalse);
      final refreshed = loader.loadText(documentPath: _path, assetPath: _asset);
      await _turn();
      expect(
        store.reads,
        1,
        reason: 'a timeout does not cancel the underlying read',
      );
      final late = results.moveNext();
      remote.complete({'content': 'late plan'});
      expect(await late, isTrue);
      expect(results.current.origin, RemoteLoadOrigin.network);
      expect(results.current.data, 'late plan');
      expect((await refreshed).data, 'late plan');
      expect(await results.moveNext(), isFalse);
    },
  );
}
