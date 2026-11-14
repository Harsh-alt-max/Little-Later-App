import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';

/// Thin wrapper over Firebase Auth. Every method returns an error message
/// suitable for a toast, or null on success.
class AuthService {
  AuthService(this.ready);

  /// False when Firebase failed to start (e.g. tests, no network on first run).
  final bool ready;
  bool _gInit = false;

  User? get user => ready ? FirebaseAuth.instance.currentUser : null;

  bool get googleAvailable => ready && googleWebClientId.isNotEmpty;

  Future<String?> email(String email, String password, {required bool signUp}) async {
    if (!ready) return 'Can’t reach Little Later right now. Check your internet.';
    try {
      if (signUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (_) {
      return 'Something went wrong. Try again.';
    }
  }

  Future<String?> google() async {
    if (!googleAvailable) return 'Google sign-in isn’t switched on yet. Use email for now.';
    try {
      if (!_gInit) {
        await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
        _gInit = true;
      }
      final acc = await GoogleSignIn.instance.authenticate();
      final idToken = acc.authentication.idToken;
      if (idToken == null) return 'Google didn’t return a sign-in token.';
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return 'cancelled';
      return 'Google sign-in failed. Try email instead.';
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (_) {
      return 'Google sign-in failed. Try email instead.';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!ready) return 'No connection.';
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    }
  }

  Future<void> signOut() async {
    if (!ready) return;
    try {
      if (_gInit) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  Future<String?> deleteAccount() async {
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return 'For safety, sign out, sign in again, then delete.';
      return _msg(e);
    }
  }

  static String _msg(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email doesn’t look right.',
        'user-not-found' || 'invalid-credential' || 'wrong-password' => 'Email or password is wrong.',
        'email-already-in-use' => 'That email already has an account. Sign in instead.',
        'weak-password' => 'Password needs at least 6 characters.',
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many tries. Wait a minute.',
        'operation-not-allowed' => 'This sign-in method isn’t switched on yet.',
        _ => e.message ?? 'Sign-in failed.',
      };
}
