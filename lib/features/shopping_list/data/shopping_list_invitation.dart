import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListInvitation {
  const ShoppingListInvitation({
    required this.id,
    required this.listId,
    required this.listName,
    required this.invitedEmail,
    required this.invitedByUserId,
    required this.invitedByName,
    required this.status,
    required this.sentAt,
    this.respondedAt,
    this.expiresAt,
  });

  final String id;
  final String listId;
  final String listName;
  final String invitedEmail;
  final String invitedByUserId;
  final String invitedByName;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime sentAt;
  final DateTime? respondedAt;
  final DateTime? expiresAt;

  factory ShoppingListInvitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShoppingListInvitation(
      id: doc.id,
      listId: data['list_id'] as String? ?? '',
      listName: data['list_name'] as String? ?? 'Shopping List',
      invitedEmail: data['invited_email'] as String? ?? '',
      invitedByUserId: data['invited_by_user_id'] as String? ?? '',
      invitedByName: data['invited_by_name'] as String? ?? 'Someone',
      status: data['status'] as String? ?? 'pending',
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['responded_at'] as Timestamp?)?.toDate(),
      expiresAt: (data['expires_at'] as Timestamp?)?.toDate(),
    );
  }
}
