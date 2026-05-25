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
  final String addedBy; // added_by_user_id
  final DateTime addedAt;
  final DateTime? boughtAt;

  factory ShoppingListItem.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] as String?)?.trim();
    final unit = (m['unit'] as String?)?.trim();
    final category = (m['category'] as String?)?.trim();

    return ShoppingListItem(
      id: m['id'].toString(),
      name: (name == null || name.isEmpty) ? 'Unnamed item' : name,
      quantity: m['quantity'] as int? ?? 1,
      unit: (unit == null || unit.isEmpty) ? null : unit,
      category: (category == null || category.isEmpty) ? null : category,
      isBought: m['is_bought'] as bool? ?? false,
      addedBy: m['added_by_user_id'] as String? ?? '',
      addedAt: m['added_at'] != null
          ? DateTime.parse(m['added_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      boughtAt: m['bought_at'] != null ? DateTime.parse(m['bought_at'] as String) : null,
    );
  }
}
