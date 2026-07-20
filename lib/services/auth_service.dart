import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Ensures the app has an (anonymous) signed-in user before calling
/// Cloud Functions or Firestore, since both are gated by request.auth.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// True once the account is only backed by anonymous auth — the daily
  /// quota is lower for these, and their history disappears on reinstall.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

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

  /// Upgrades the current (anonymous) account to a Google-backed one,
  /// preserving the uid and any data already stored under it.
  Future<User> linkWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw StateError('已取消 Google 登入。');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _linkOrSignIn(credential);
  }

  /// Upgrades the current (anonymous) account to an Apple-backed one,
  /// preserving the uid and any data already stored under it.
  Future<User> linkWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return _linkOrSignIn(credential);
  }

  /// Links [credential] onto the current anonymous user when possible so the
  /// uid (and any data under it) is preserved. If that provider account is
  /// already tied to a different Firebase user (e.g. previously linked on
  /// another device), falls back to signing straight into it instead —
  /// leaving the anonymous data behind on this device.
  Future<User> _linkOrSignIn(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithCredential(credential);
        final user = result.user;
        if (user == null) {
          throw StateError('Linking returned a null user.');
        }
        return user;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw StateError('Sign-in returned a null user.');
    }
    return user;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
