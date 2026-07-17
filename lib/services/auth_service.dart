import 'package:firebase_auth/firebase_auth.dart';

/// Ensures the app has an (anonymous) signed-in user before calling
/// Cloud Functions or Firestore, since both are gated by request.auth.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<User> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current;

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned a null user.');
    }
    return user;
  }
}
