import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    this.brand,
    required this.quantity,
    this.unit,
    required this.isBought,
    required this.addedBy,
    required this.addedAt,
    this.boughtAt,
  });

  final String id;
  final String name;
  final String? brand;
  final int quantity;
  final String? unit;
  final bool isBought;
  final String addedBy;
  final DateTime addedAt;
  final DateTime? boughtAt;

  factory ShoppingListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data?['name'] as String?)?.trim();
    final brand = (data?['brand'] as String?)?.trim();
    final unit = (data?['unit'] as String?)?.trim();
    final isBought = data?['is_bought'] as bool? ?? false;
    final addedAt = data?['added_at'] as Timestamp?;
    final boughtAt = data?['bought_at'] as Timestamp?;

    return ShoppingListItem(
      id: doc.id,
      name: (name == null || name.isEmpty) ? 'Unnamed item' : name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      quantity: data?['quantity'] as int? ?? 1,
      unit: (unit == null || unit.isEmpty) ? null : unit,
      isBought: isBought,
      addedBy: data?['added_by'] as String? ?? '',
      addedAt: addedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      boughtAt: boughtAt?.toDate(),
    );
  }
}
