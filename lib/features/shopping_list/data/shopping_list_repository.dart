import 'package:cloud_firestore/cloud_firestore.dart';

import 'shopping_list_item.dart';

class ShoppingListRepository {
  ShoppingListRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _shoppingListItems(String uid) => _firestore.collection('users').doc(uid).collection('shopping_list');

  Stream<List<ShoppingListItem>> watchItems(String uid) {
    return _shoppingListItems(uid).orderBy('added_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map(ShoppingListItem.fromDoc).toList(growable: false);
    });
  }

  Future<void> addItem({required String uid, required String name, String? brand}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedBrand = brand?.trim();

    await _shoppingListItems(uid).add({
      'name': trimmedName,
      'brand': (trimmedBrand == null || trimmedBrand.isEmpty) ? null : trimmedBrand,
      'added_at': FieldValue.serverTimestamp(),
    });
  }
}
