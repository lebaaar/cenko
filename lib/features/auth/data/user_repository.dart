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

  Future<void> deleteUser(String uid) async {
    final userDoc = _users.doc(uid);

    final receipts = await userDoc.collection('receipts').get();
    for (final receipt in receipts.docs) {
      final items = await receipt.reference.collection('items').get();
      for (final item in items.docs) {
        await item.reference.delete();
      }
      await receipt.reference.delete();
    }

    final shoppingList = await userDoc.collection('shopping_list').get();
    for (final doc in shoppingList.docs) {
      await doc.reference.delete();
    }

    final commonProducts = await userDoc.collection('common_products').get();
    for (final doc in commonProducts.docs) {
      await doc.reference.delete();
    }

    await userDoc.delete();
  }

  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }
}
