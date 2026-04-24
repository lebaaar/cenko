import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListMembership {
  const ShoppingListMembership({
    required this.listId,
    required this.name,
    required this.joinedAt,
  });

  final String listId;
  final String name;
  final DateTime joinedAt;

  factory ShoppingListMembership.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShoppingListMembership(
      listId: doc.id,
      name: data['name'] as String? ?? 'Shopping List',
      joinedAt: (data['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
