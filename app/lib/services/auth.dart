import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over Firebase Auth. Methods return an error message for a
/// toast, null on success, or [AuthService.verify] when the email still needs
/// confirming.
class AuthService {
  AuthService(this.ready);

  /// False when Firebase failed to start (tests, or no network on first run).
  final bool ready;

  static const verify = 'verify';

  User? get user => ready ? FirebaseAuth.instance.currentUser : null;

  /// Google accounts are already verified; email accounts must click the link.
  bool get verified {
    final u = user;
    if (u == null) return false;
    return u.emailVerified || u.providerData.any((p) => p.providerId == 'google.com');
  }

  Future<String?> email(String email, String password, {required bool signUp}) async {
    if (!ready) return 'Can’t reach Little Later right now. Check your internet.';
    try {
      final auth = FirebaseAuth.instance;
      final cred = signUp
          ? await auth.createUserWithEmailAndPassword(email: email.trim(), password: password)
          : await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final u = cred.user;
      if (u != null && !u.emailVerified) {
        await u.sendEmailVerification();
        return verify;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (_) {
      return 'Something went wrong. Try again.';
    }
  }

  /// Re-checks the verification link. Returns true once the email is confirmed.
  Future<bool> checkVerified() async {
    final u = user;
    if (u == null) return false;
    try {
      await u.reload();
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  }

  Future<String?> resendVerification() async {
    try {
      await user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    }
  }

  /// Google sign-in through Firebase's own Google flow (a Google account page
  /// opens, then returns to the app).
  Future<String?> google() async {
    if (!ready) return 'Can’t reach Little Later right now. Check your internet.';
    try {
      final p = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
      await FirebaseAuth.instance.signInWithProvider(p);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled' || e.code == 'user-cancelled') return 'cancelled';
      return _msg(e);
    } catch (_) {
      return 'Google sign-in failed. Try again.';
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
        'user-not-found' || 'invalid-credential' || 'wrong-password' || 'INVALID_LOGIN_CREDENTIALS' => 'Email or password is wrong.',
        'email-already-in-use' => 'That email already has an account. Sign in instead.',
        'weak-password' => 'Password needs at least 6 characters.',
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many tries. Wait a minute.',
        'operation-not-allowed' => 'This sign-in method isn’t switched on yet.',
        'internal-error' when (e.message ?? '').contains('CONFIGURATION') => 'Google sign-in needs one more setup step in Firebase.',
        _ => e.message ?? 'Sign-in failed.',
      };
}
