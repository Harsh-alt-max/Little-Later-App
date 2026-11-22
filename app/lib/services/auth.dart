import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

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
      // A fresh token carries the new "verified" flag to the database rules.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    return verified || (FirebaseAuth.instance.currentUser?.emailVerified ?? false);
  }

  Future<String?> resendVerification() async {
    try {
      await user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    }
  }

  /// Google sign-in: opens our sign-in page in Chrome (fast, uses the
  /// accounts already on the phone), which hands the Google token back to the
  /// app through a littlelater://auth link.
  Completer<String?>? _pending;
  Timer? _resumeTimer;

  Future<String?> google() async {
    if (!ready) return 'Can’t reach Little Later right now. Check your internet.';
    _pending?.complete('cancelled');
    final c = _pending = Completer<String?>();
    final ok = await launchUrl(Uri.parse('$siteUrl/app-auth.html'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) {
      _pending = null;
      return 'Couldn’t open the browser. Try again.';
    }
    return c.future.timeout(const Duration(minutes: 4), onTimeout: () => 'cancelled');
  }

  /// littlelater://auth?id=…&at=… from the sign-in page.
  Future<void> handleLink(Uri u) async {
    _resumeTimer?.cancel();
    final c = _pending;
    _pending = null;
    final id = u.queryParameters['id'], at = u.queryParameters['at'];
    if (id == null && at == null) {
      c?.complete('Google sign-in failed. Try again.');
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: id, accessToken: at));
      c?.complete(null);
    } on FirebaseAuthException catch (e) {
      c?.complete(_msg(e));
    } catch (_) {
      c?.complete('Google sign-in failed. Try again.');
    }
  }

  /// Back in the app without a sign-in link: treat it as cancelled.
  void onResumed() {
    if (_pending == null) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 6), () {
      _pending?.complete('cancelled');
      _pending = null;
    });
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
