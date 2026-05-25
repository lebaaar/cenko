import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/features/shopping_list/data/category.dart';
import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_invitation.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedShoppingListRepository {
  final _client = Supabase.instance.client;

  static const _listSelect =
      'id, name, created_by_user_id, created_at, updated_at, '
      'shopping_list_member(user_id, role, joined_at, user:user_id(display_name))';

  static const _invitationSelect =
      'id, invited_user_id, invited_by_user_id, shopping_list_id, sent_at, '
      'shopping_list(name), '
      'invited_by:user!invited_by_user_id(display_name), '
      'invited:user!invited_user_id(email, display_name)';

  // ── Lists ────────────────────────────────────────────────────────────────

  Future<ShoppingList?> getList(String listId) async {
    final row = await _client.from('shopping_list').select(_listSelect).eq('id', int.parse(listId)).maybeSingle();
    return row == null ? null : ShoppingList.fromMap(row);
  }

  Future<String> createList({required String ownerUid, required String ownerName, required String name, bool isFreePlan = false}) async {
    if (isFreePlan) {
      final rows = await _client.from('shopping_list_member').select('shopping_list_id').eq('user_id', ownerUid);
      if ((rows as List).length >= kMaxNumberOfShoppingLists) {
        throw Exception('You have reached the maximum of $kMaxNumberOfShoppingLists shopping lists');
      }
    }

    final trimmedName = name.trim();
    final listRow = await _client.from('shopping_list').insert({'name': trimmedName, 'created_by_user_id': ownerUid}).select('id').single();

    final listId = listRow['id'] as int;

    await _client.from('shopping_list_member').insert({'shopping_list_id': listId, 'user_id': ownerUid, 'role': 'owner'});

    return listId.toString();
  }

  Future<void> renameList({required String listId, required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    await _client.from('shopping_list').update({'name': trimmedName}).eq('id', int.parse(listId));
  }

  Future<void> deleteList({required String listId}) async {
    // ON DELETE CASCADE removes shopping_list_member and shopping_list_item rows.
    await _client.from('shopping_list').delete().eq('id', int.parse(listId));
  }

  Future<void> leaveList({required String uid, required String listId}) async {
    await _client.from('shopping_list_member').delete().eq('shopping_list_id', int.parse(listId)).eq('user_id', uid);
  }

  Future<void> removeMember({required String listId, required String memberUid}) async {
    await _client.from('shopping_list_member').delete().eq('shopping_list_id', int.parse(listId)).eq('user_id', memberUid);
  }

  Future<void> transferOwnership({required String listId, required String currentOwnerUid, required String newOwnerUid}) async {
    final id = int.parse(listId);
    await _client.from('shopping_list_member').update({'role': 'member'}).eq('shopping_list_id', id).eq('user_id', currentOwnerUid);
    await _client.from('shopping_list_member').update({'role': 'owner'}).eq('shopping_list_id', id).eq('user_id', newOwnerUid);
    await _client.from('shopping_list').update({'created_by_user_id': newOwnerUid}).eq('id', id);
  }

  Future<List<ShoppingList>> getUserLists(String uid) async {
    final memberRows = await _client.from('shopping_list_member').select('shopping_list_id').eq('user_id', uid);
    if ((memberRows as List).isEmpty) return [];
    final listIds = memberRows.map((r) => r['shopping_list_id']).toList();
    final rows = await _client.from('shopping_list').select(_listSelect).inFilter('id', listIds);
    return (rows as List).map((r) => ShoppingList.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String?> getPrimaryListId(String uid) async {
    final rows = await _client.from('shopping_list_member').select('shopping_list_id').eq('user_id', uid).order('joined_at').limit(1);
    if ((rows as List).isEmpty) return null;
    return rows.first['shopping_list_id'].toString();
  }

  // ── Categories ───────────────────────────────────────────────────────────

  Future<List<Category>> getCategories() async {
    final rows = await _client.from('category').select().order('id', ascending: true);
    return (rows as List).map((r) => Category.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── Items ────────────────────────────────────────────────────────────────

  Future<List<ShoppingListItem>> getItems(String listId) async {
    final rows = await _client.from('shopping_list_item').select().eq('shopping_list_id', int.parse(listId)).order('added_at', ascending: false);
    return (rows as List).map((r) => ShoppingListItem.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addItem({
    required String listId,
    required String addedBy,
    required String name,
    int quantity = 1,
    String? unit,
    int? categoryId,
    bool isFreePlan = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    if (isFreePlan) {
      final rows = await _client.from('shopping_list_item').select('id').eq('shopping_list_id', int.parse(listId));
      if ((rows as List).length >= kMaxNumberOfItemsPerList) {
        throw Exception('This list has reached the maximum of $kMaxNumberOfItemsPerList items');
      }
    }

    final trimmedUnit = unit?.trim();

    await _client.from('shopping_list_item').insert({
      'name': trimmedName,
      'shopping_list_id': int.parse(listId),
      'added_by_user_id': addedBy,
      'quantity': quantity,
      if (trimmedUnit != null && trimmedUnit.isNotEmpty) 'unit': trimmedUnit,
      'category_id': ?categoryId,
    });

    await _client.from('shopping_list').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', int.parse(listId));
  }

  Future<void> updateItem({
    required String listId,
    required String itemId,
    required String name,
    int? quantity,
    String? unit,
    int? categoryId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedUnit = unit?.trim();

    await _client
        .from('shopping_list_item')
        .update({
          'name': trimmedName,
          'quantity': ?quantity,
          'unit': (trimmedUnit == null || trimmedUnit.isEmpty) ? null : trimmedUnit,
          'category_id': categoryId,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', int.parse(itemId));
  }

  Future<void> setBought({required String listId, required String itemId, required bool bought}) async {
    await _client
        .from('shopping_list_item')
        .update({'is_bought': bought, 'bought_at': bought ? DateTime.now().toUtc().toIso8601String() : null})
        .eq('id', int.parse(itemId));
  }

  Future<void> deleteItem({required String listId, required String itemId, required bool wasBought}) async {
    await _client.from('shopping_list_item').delete().eq('id', int.parse(itemId));
    await _client.from('shopping_list').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', int.parse(listId));
  }

  // ── Invitations ──────────────────────────────────────────────────────────

  Future<List<ShoppingListInvitation>> getPendingInvitations(String userId) async {
    final rows = await _client.from('shopping_list_invitation').select(_invitationSelect).eq('invited_user_id', userId);
    return (rows as List).map((r) => ShoppingListInvitation.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<ShoppingListInvitation>> getListPendingInvitations(String listId) async {
    final rows = await _client.from('shopping_list_invitation').select(_invitationSelect).eq('shopping_list_id', int.parse(listId));
    return (rows as List).map((r) => ShoppingListInvitation.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> inviteByEmail({
    required String listId,
    required String listName,
    required String invitedByUid,
    required String invitedByName,
    required String email,
    bool isFreePlan = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final id = int.parse(listId);

    // Resolve email → user id
    final userRows = await _client.from('user').select('id').eq('email', normalizedEmail).limit(1);
    if ((userRows as List).isEmpty) {
      throw Exception('No user with that email address was found');
    }
    final invitedUid = userRows.first['id'] as String;

    // Current members
    final memberRows = await _client.from('shopping_list_member').select('user_id').eq('shopping_list_id', id);
    final members = memberRows as List;

    if (members.any((m) => m['user_id'] == invitedUid)) {
      throw Exception('User is already a member of this list');
    }
    if (members.length >= kMaxNumbberOfMembersPerSharedList) {
      throw Exception('This list has reached the maximum of $kMaxNumbberOfMembersPerSharedList members');
    }

    // Pending invitations
    final pendingRows = await _client.from('shopping_list_invitation').select('id').eq('shopping_list_id', id);
    if (members.length + (pendingRows as List).length >= kMaxNumbberOfMembersPerSharedList) {
      throw Exception(
        'List has too many pending invitations — cancel some first '
        '(maximum is $kMaxNumbberOfMembersPerSharedList members per list)',
      );
    }

    // Duplicate invitation check
    final existing = await _client
        .from('shopping_list_invitation')
        .select('id')
        .eq('shopping_list_id', id)
        .eq('invited_user_id', invitedUid)
        .limit(1);
    if ((existing as List).isNotEmpty) {
      throw Exception('User has already been invited to this list');
    }

    await _client.from('shopping_list_invitation').insert({
      'shopping_list_id': id,
      'invited_by_user_id': invitedByUid,
      'invited_user_id': invitedUid,
      'expires_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    });
  }

  Future<void> acceptInvitation({required String invitationId, required String listId, required String uid, bool isFreePlan = false}) async {
    if (isFreePlan) {
      final rows = await _client.from('shopping_list_member').select('shopping_list_id').eq('user_id', uid);
      if ((rows as List).length >= kMaxNumberOfShoppingLists) {
        throw Exception('You have reached the maximum of $kMaxNumberOfShoppingLists shopping lists');
      }
    }

    await _client.from('shopping_list_member').insert({'shopping_list_id': int.parse(listId), 'user_id': uid, 'role': 'member'});

    await _client.from('shopping_list_invitation').delete().eq('id', int.parse(invitationId));
  }

  Future<void> declineInvitation(String invitationId) async {
    await _client.from('shopping_list_invitation').delete().eq('id', int.parse(invitationId));
  }

  Future<void> cancelInvitation(String invitationId) async {
    await _client.from('shopping_list_invitation').delete().eq('id', int.parse(invitationId));
  }
}
