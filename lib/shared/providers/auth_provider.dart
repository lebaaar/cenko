import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// ChangeNotifier that pings GoRouter whenever auth state changes.
class AuthNotifier extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _userRepo = UserRepository();

  AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  String _fallbackName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'User';
  }

  Future<void> _ensureUserDocument({required User user, required String authProvider, String? name, String? googleId}) async {
    if (await _userRepo.userExists(user.uid)) {
      return;
    }

    await _userRepo.saveUser(
      UserModel(
        userId: user.uid,
        name: name?.trim().isNotEmpty == true ? name!.trim() : _fallbackName(user),
        email: user.email ?? '',
        createdAt: DateTime.now(),
        authProvider: authProvider,
        googleId: googleId,
      ),
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user: user, authProvider: 'email');
    }
  }

  Future<void> registerWithEmail(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user!;
    await user.updateDisplayName(displayName);
    await _ensureUserDocument(user: user, authProvider: 'email', name: displayName);
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;
    await _ensureUserDocument(user: user, authProvider: 'google', googleId: googleUser.id);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), GoogleSignIn.instance.signOut()]);
  }

  Future<void> deleteAccount(String uid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userRepo.deleteUser(uid);
    await user.delete();
    await GoogleSignIn.instance.signOut();
  }
}

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier(ref);
});
