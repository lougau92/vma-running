import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show Firebase;

import 'firebase_options.dart' show DefaultFirebaseOptions;

/// Initializes Firebase lazily and shares concurrent anonymous sign-ins.
class FirebaseContentSession {
  FirebaseContentSession({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;
  Future<void>? _pending;

  Future<void> ensureSignedIn() =>
      _pending ??= _ensureSession().whenComplete(() => _pending = null);

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
