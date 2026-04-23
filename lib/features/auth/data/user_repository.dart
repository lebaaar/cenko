import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class UserRepository {
  final _users = FirebaseFirestore.instance.collection('users');

  Future<void> saveUser(UserModel user) async {
    await _users.doc(user.userId).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await _users.doc(uid).update({'name': name.trim()});
  }

  Future<void> updateSettings(String uid, UserSettings settings) async {
    await _users.doc(uid).update({'settings': settings.toMap()});
  }

  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }
}
