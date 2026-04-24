import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListMember {
  const ShoppingListMember({
    required this.userId,
    required this.name,
    required this.joinedAt,
    required this.role,
  });

  final String userId;
  final String name;
  final DateTime joinedAt;
  final String role; // 'owner' | 'member'

  factory ShoppingListMember.fromMap(Map<String, dynamic> m) {
    return ShoppingListMember(
      userId: m['user_id'] as String? ?? '',
      name: m['name'] as String? ?? 'Unknown',
      joinedAt: (m['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      role: m['role'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'name': name,
    'joined_at': Timestamp.fromDate(joinedAt),
    'role': role,
  };
}

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.boughtCount,
    required this.members,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;
  final int boughtCount;
  final List<ShoppingListMember> members;

  factory ShoppingList.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final members = (data['members'] as List<dynamic>? ?? [])
        .map((m) => ShoppingListMember.fromMap(m as Map<String, dynamic>))
        .toList();

    return ShoppingList(
      id: doc.id,
      name: data['name'] as String? ?? 'Shopping List',
      ownerId: data['owner_id'] as String? ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      itemCount: data['item_count'] as int? ?? 0,
      boughtCount: data['bought_count'] as int? ?? 0,
      members: members,
    );
  }
}
