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
    final userMap = m['user'] as Map<String, dynamic>?;
    return ShoppingListMember(
      userId: m['user_id'] as String? ?? '',
      name: userMap?['display_name'] as String? ?? 'Unknown',
      joinedAt: m['joined_at'] != null ? DateTime.parse(m['joined_at'] as String) : DateTime.now(),
      role: m['role'] as String? ?? 'member',
    );
  }
}

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
  });

  final String id;
  final String name;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingListMember> members;

  /// Compatibility getter — maps to createdByUserId.
  String get ownerId => createdByUserId;

  factory ShoppingList.fromMap(Map<String, dynamic> m) {
    final rawMembers = m['shopping_list_member'] as List<dynamic>? ?? [];
    final members = rawMembers
        .map((mem) => ShoppingListMember.fromMap(mem as Map<String, dynamic>))
        .toList();

    return ShoppingList(
      id: m['id'].toString(),
      name: m['name'] as String? ?? 'Shopping List',
      createdByUserId: m['created_by_user_id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      members: members,
    );
  }
}
