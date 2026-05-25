class ShoppingListInvitation {
  const ShoppingListInvitation({
    required this.id,
    required this.listId,
    required this.listName,
    required this.invitedUserId,
    required this.invitedEmail,
    required this.invitedByUserId,
    required this.invitedByName,
    required this.sentAt,
  });

  final String id;
  final String listId;
  final String listName;
  final String invitedUserId;
  final String invitedEmail; // from join with "user" table
  final String invitedByUserId;
  final String invitedByName; // from join with "user" table
  final DateTime sentAt;

  factory ShoppingListInvitation.fromMap(Map<String, dynamic> m) {
    final listMap = m['shopping_list'] as Map<String, dynamic>?;
    // Alias 'invited_by' is used when embedding inviting user
    final invitedByMap = m['invited_by'] as Map<String, dynamic>?;
    // Alias 'invited' is used when embedding invited user
    final invitedMap = m['invited'] as Map<String, dynamic>?;

    return ShoppingListInvitation(
      id: m['id'].toString(),
      listId: m['shopping_list_id'].toString(),
      listName: listMap?['name'] as String? ?? 'Shopping List',
      invitedUserId: m['invited_user_id'] as String? ?? '',
      invitedEmail: invitedMap?['email'] as String? ?? '',
      invitedByUserId: m['invited_by_user_id'] as String? ?? '',
      invitedByName: invitedByMap?['display_name'] as String? ?? 'Someone',
      sentAt: m['sent_at'] != null
          ? DateTime.parse(m['sent_at'] as String)
          : DateTime.now(),
    );
  }
}
