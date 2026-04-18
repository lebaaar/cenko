import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListItem {
  const ShoppingListItem({required this.id, required this.name, this.brand, this.barcode, required this.bought, required this.addedAt});

  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final bool bought;
  final DateTime addedAt;

  factory ShoppingListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data?['name'] as String?)?.trim();
    final brand = (data?['brand'] as String?)?.trim();
    final barcode = (data?['barcode'] as String?)?.trim();
    final bought = data?['bought'] as bool? ?? false;
    final addedAtTs = data?['added_at'] as Timestamp?;

    return ShoppingListItem(
      id: doc.id,
      name: (name == null || name.isEmpty) ? 'Unnamed item' : name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      barcode: (barcode == null || barcode.isEmpty) ? null : barcode,
      bought: bought,
      addedAt: addedAtTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
