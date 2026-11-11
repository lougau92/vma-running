import 'dart:async' show Completer;

import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentReference, FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException, User, UserCredential;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:vma_running/firebase_content_session.dart'
    show FirebaseContentSession;
import 'package:vma_running/remote_asset_loader.dart'
    show RemoteAssetLoader, RemoteLoadOrigin;

class _User extends Fake implements User {}

class _Credential extends Fake implements UserCredential {}

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  int signIns = 0;
  Object? failure;
  Completer<void>? blocker;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInAnonymously() async {
    signIns++;
    if (blocker != null) await blocker!.future;
    if (failure != null) throw failure!;
    user = _User();
    return _Credential();
  }
}

class _OfflineSession extends FirebaseContentSession {
  @override
  Future<void> ensureSignedIn() async =>
      throw FirebaseAuthException(code: 'network-request-failed');
}

class _DeferredSession extends FirebaseContentSession {
  final ready = Completer<void>();
  @override
  Future<void> ensureSignedIn() => ready.future;
}

class _Firestore extends Fake implements FirebaseFirestore {
  int reads = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    reads++;
    throw StateError('Remote read failed after session setup');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reuses a persisted Firebase session without signing in again',
    () async {
      final auth = _Auth()..user = _User();
      await FirebaseContentSession(auth: auth).ensureSignedIn();
      expect(auth.signIns, 0);
    },
  );

  test(
    'concurrent reads share one anonymous sign-in and reuse its user',
    () async {
      final auth = _Auth()..blocker = Completer<void>();
      final session = FirebaseContentSession(auth: auth);
      final first = session.ensureSignedIn();
      final second = session.ensureSignedIn();
      expect(auth.signIns, 1);
      auth.blocker!.complete();
      await Future.wait([first, second]);
      await session.ensureSignedIn();
      expect(auth.signIns, 1);
      expect(auth.user, isNotNull);
    },
  );

  test(
    'a failed anonymous sign-in can be retried after reconnecting',
    () async {
      final auth = _Auth()
        ..failure = FirebaseAuthException(code: 'network-request-failed');
      final session = FirebaseContentSession(auth: auth);
      await expectLater(
        session.ensureSignedIn(),
        throwsA(isA<FirebaseAuthException>()),
      );
      auth.failure = null;
      await session.ensureSignedIn();
      expect(auth.signIns, 2);
    },
  );

  test(
    'offline sign-in falls back to bundled data without touching Firestore',
    () async {
      final firestore = _Firestore();
      final result =
          await RemoteAssetLoader(
            firestore: firestore,
            session: _OfflineSession(),
          ).loadText(
            documentPath: 'app_documents/training_plan',
            assetPath: 'assets/training_plans/training_example.json',
          );
      expect(result.origin, RemoteLoadOrigin.asset);
      expect(result.data, contains('groups'));
      expect(result.error, isA<FirebaseAuthException>());
      expect(firestore.reads, 0);
    },
  );

  test('fallback logs the Firebase code without exception details', () async {
    final messages = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = original);
    final auth = _Auth()
      ..failure = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'private-token-and-document-content',
      );
    await RemoteAssetLoader(
      session: FirebaseContentSession(auth: auth),
    ).loadText(
      documentPath: 'app_documents/training_plan',
      assetPath: 'assets/training_plans/training_example.json',
    );
    expect(messages, [
      'Remote content load failed (firebase_auth/network-request-failed); '
          'using local fallback.',
    ]);
  });

  test('Firestore is accessed only after session setup completes', () async {
    final firestore = _Firestore();
    final session = _DeferredSession();
    final pending = RemoteAssetLoader(firestore: firestore, session: session)
        .loadText(
          documentPath: 'app_documents/training_plan',
          assetPath: 'assets/training_plans/training_example.json',
        );
    expect(firestore.reads, 0);
    session.ready.complete();
    final result = await pending;
    expect(firestore.reads, 1);
    expect(result.origin, RemoteLoadOrigin.asset);
  });
}
