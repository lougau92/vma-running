import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show Firebase;

import 'firebase_options.dart' show DefaultFirebaseOptions;

/// Initializes Firebase lazily and shares concurrent anonymous sign-ins.
class FirebaseContentSession {
  FirebaseContentSession({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;
  Future<void>? _pending;
  static Future<void>? _defaultPending;

  Future<void> ensureSignedIn() {
    if (_auth == null) {
      return _defaultPending ??= _ensureSession().whenComplete(
        () => _defaultPending = null,
      );
    }
    return _pending ??= _ensureSession().whenComplete(() => _pending = null);
  }

  Future<String> idToken({bool forceRefresh = false}) async {
    await ensureSignedIn();
    final token = await (_auth ?? FirebaseAuth.instance).currentUser!
        .getIdToken(forceRefresh);
    if (token == null) throw StateError('Firebase token unavailable');
    return token;
  }

  Future<String> userId() async {
    await ensureSignedIn();
    return (_auth ?? FirebaseAuth.instance).currentUser!.uid;
  }

  Future<void> _ensureSession() async {
    if (_auth == null && Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final auth = _auth ?? FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
  }
}
