import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:cenko/shared/providers/auth_locale_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when account deletion is blocked because the user owns shared lists.
class OwnedSharedListsException implements Exception {
  const OwnedSharedListsException(this.listNames);
  final List<String> listNames;
}

final _supabase = Supabase.instance.client;

final authStateProvider = StreamProvider<Session?>((ref) {
  return _supabase.auth.onAuthStateChange.map((event) => event.session);
});

class AuthNotifier extends ChangeNotifier {
  final _auth = Supabase.instance.client.auth;
  final Ref _ref;

  AuthNotifier(Ref ref) : _ref = ref {
    ref.listen(authStateProvider, (prev, next) => notifyListeners());
  }

  Future<void> signInWithEmail(String email, String password) async {
    final language = _ref.read(authLocaleProvider);
    await _auth.signInWithPassword(email: email, password: password);
    final uid = _auth.currentSession?.user.id;
    if (uid != null) await UserRepository().updateSettings(uid, lang: language);
    await clearAuthLocale();
  }

  Future<void> registerWithEmail(String email, String password, String displayName) async {
    final language = _ref.read(authLocaleProvider);
    await _auth.signUp(email: email, password: password, data: {'display_name': displayName, 'auth_provider': 'email', 'lang': language});
    // Also update user row directly — metadata-based trigger may not set lang
    final uid = _auth.currentSession?.user.id;
    if (uid != null) await UserRepository().updateSettings(uid, lang: language);
    await clearAuthLocale();
  }

  Future<void> signInWithGoogle() async {
    final language = _ref.read(authLocaleProvider);
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google sign-in failed: no ID token');

    await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);

    final uid = _auth.currentSession?.user.id;
    if (uid != null) await UserRepository().updateSettings(uid, lang: language);
    await clearAuthLocale();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), GoogleSignIn.instance.signOut()]);
  }

  Future<void> deleteAccount() async {
    try {
      await _supabase.functions.invoke('delete-my-account');
    } on FunctionException catch (e) {
      final data = e.details;
      if (e.status == 409 && data is Map && data['owned_lists'] != null) {
        throw OwnedSharedListsException(List<String>.from(data['owned_lists'] as List));
      }
      throw Exception((data is Map ? data['error'] : null) ?? 'Failed to delete account');
    }
    // Auth user deleted server-side — clear local session so authStateProvider
    // emits null and the router redirects to login.
    await Future.wait([_auth.signOut(scope: SignOutScope.local), GoogleSignIn.instance.signOut()]);
  }
}

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier(ref);
});
