import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit,
    this.category,
    required this.isBought,
    required this.addedBy,
    required this.addedAt,
    this.boughtAt,
  });

  final String id;
  final String name;
  final int quantity;
  final String? unit;
  final String? category;
  final bool isBought;
  final String addedBy;
  final DateTime addedAt;
  final DateTime? boughtAt;

  factory ShoppingListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data?['name'] as String?)?.trim();
    final unit = (data?['unit'] as String?)?.trim();
    final category = (data?['category'] as String?)?.trim();
    final isBought = data?['is_bought'] as bool? ?? false;
    final addedAt = data?['added_at'] as Timestamp?;
    final boughtAt = data?['bought_at'] as Timestamp?;

    return ShoppingListItem(
      id: doc.id,
      name: (name == null || name.isEmpty) ? 'Unnamed item' : name,
      quantity: data?['quantity'] as int? ?? 1,
      unit: (unit == null || unit.isEmpty) ? null : unit,
      category: (category == null || category.isEmpty) ? null : category,
      isBought: isBought,
      addedBy: data?['added_by'] as String? ?? '',
      addedAt: addedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      boughtAt: boughtAt?.toDate(),
    );
  }
}
