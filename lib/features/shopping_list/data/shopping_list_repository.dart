import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/user_util.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListRepository {
  ShoppingListRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _shoppingListItems(String uid) => _firestore.collection('users').doc(uid).collection('shopping_list');

  Stream<List<ShoppingListItem>> watchItems(String uid) {
    return _shoppingListItems(uid).orderBy('added_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map(ShoppingListItem.fromDoc).toList(growable: false);
    });
  }

  Future<void> addItem({required String uid, required String name, String? brand, String? barcode}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    if (await isFreePlan(_firestore, uid)) {
      final countSnap = await _shoppingListItems(uid).count().get();
      if ((countSnap.count ?? 0) >= kMaxNumberOfItemsPerList) {
        throw Exception('You have reached the maximum of $kMaxNumberOfItemsPerList items in your shopping list');
      }
    }

    final trimmedBrand = brand?.trim();
    final trimmedBarcode = barcode?.trim();

    await _shoppingListItems(uid).add({
      'name': trimmedName,
      'brand': (trimmedBrand == null || trimmedBrand.isEmpty) ? null : trimmedBrand,
      'barcode': (trimmedBarcode == null || trimmedBarcode.isEmpty) ? null : trimmedBarcode,
      'bought': false,
      'added_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem({required String uid, required String itemId, required String name, String? brand, String? barcode}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedBrand = brand?.trim();
    final trimmedBarcode = barcode?.trim();

    await _shoppingListItems(uid).doc(itemId).update({
      'name': trimmedName,
      'brand': (trimmedBrand == null || trimmedBrand.isEmpty) ? null : trimmedBrand,
      'barcode': (trimmedBarcode == null || trimmedBarcode.isEmpty) ? null : trimmedBarcode,
    });
  }

  Future<void> setBought({required String uid, required String itemId, required bool bought}) async {
    await _shoppingListItems(uid).doc(itemId).update({'bought': bought});
  }

  Future<void> deleteItem({required String uid, required String itemId}) async {
    await _shoppingListItems(uid).doc(itemId).delete();
  }
}
