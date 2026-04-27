import 'dart:async';

import 'package:cenko/core/constants/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'shopping_list.dart';
import 'shopping_list_invitation.dart';
import 'shopping_list_item.dart';

class SharedShoppingListRepository {
  SharedShoppingListRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _lists => _firestore.collection('shopping_lists');

  CollectionReference<Map<String, dynamic>> get _invitations => _firestore.collection('shopping_list_invitations');

  CollectionReference<Map<String, dynamic>> _memberships(String uid) =>
      _firestore.collection('users').doc(uid).collection('shopping_lists_memberships');

  CollectionReference<Map<String, dynamic>> _items(String listId) => _lists.doc(listId).collection('items');

  Future<String> createList({required String ownerUid, required String ownerName, required String name}) async {
    final existing = await getUserLists(ownerUid);
    if (existing.length >= maxNumberOfShoppingLists) {
      throw Exception('You have reached the maximum of $maxNumberOfShoppingLists shopping lists');
    }

    final listRef = _lists.doc();
    final now = Timestamp.now();
    final trimmedName = name.trim();

    final batch = _firestore.batch();

    batch.set(listRef, {
      'name': trimmedName,
      'owner_id': ownerUid,
      'created_at': now,
      'updated_at': now,
      'item_count': 0,
      'bought_count': 0,
      'members': [
        {'user_id': ownerUid, 'name': ownerName, 'joined_at': now, 'role': 'owner'},
      ],
    });

    batch.set(_memberships(ownerUid).doc(listRef.id), {'list_id': listRef.id, 'name': trimmedName, 'joined_at': now});

    await batch.commit();
    return listRef.id;
  }

  /// Streams all lists the user is a member of, in real-time.
  /// Internally merges the membership subcollection stream with individual list document streams.
  Stream<List<ShoppingList>> watchUserLists(String uid) {
    final controller = StreamController<List<ShoppingList>>();
    final Map<String, ShoppingList> listsById = {};
    final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> listSubs = {};
    StreamSubscription? membershipSub;

    void emit() {
      if (!controller.isClosed) {
        final sorted = listsById.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        controller.add(sorted);
      }
    }

    membershipSub = _memberships(uid).snapshots().listen(
      (snapshot) {
        final currentIds = snapshot.docs.map((d) => d.id).toSet();

        for (final id in listSubs.keys.toList()) {
          if (!currentIds.contains(id)) {
            listSubs.remove(id)?.cancel();
            listsById.remove(id);
          }
        }

        for (final id in currentIds) {
          if (!listSubs.containsKey(id)) {
            listSubs[id] = _lists.doc(id).snapshots().listen((doc) {
              if (doc.exists) {
                listsById[id] = ShoppingList.fromDoc(doc);
              } else {
                listsById.remove(id);
              }
              emit();
            }, onError: controller.addError);
          }
        }

        emit();
      },
      onError: controller.addError,
      onDone: controller.close,
    );

    controller.onCancel = () {
      membershipSub?.cancel();
      for (final sub in listSubs.values) {
        sub.cancel();
      }
      listSubs.clear();
      listsById.clear();
    };

    return controller.stream;
  }

  Stream<ShoppingList?> watchList(String listId) {
    return _lists.doc(listId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShoppingList.fromDoc(doc);
    });
  }

  Stream<List<ShoppingListItem>> watchItems(String listId) {
    return _items(
      listId,
    ).orderBy('added_at', descending: false).snapshots().map((snap) => snap.docs.map(ShoppingListItem.fromDoc).toList(growable: false));
  }

  Future<void> addItem({required String listId, required String addedBy, required String name, int quantity = 1, String? unit}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedUnit = unit?.trim();

    final batch = _firestore.batch();
    final itemRef = _items(listId).doc();

    batch.set(itemRef, {
      'name': trimmedName,
      'quantity': quantity,
      'unit': (trimmedUnit == null || trimmedUnit.isEmpty) ? null : trimmedUnit,
      'is_bought': false,
      'added_by': addedBy,
      'added_at': FieldValue.serverTimestamp(),
      'bought_at': null,
    });

    batch.update(_lists.doc(listId), {'item_count': FieldValue.increment(1), 'updated_at': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  Future<void> updateItem({required String listId, required String itemId, required String name, int? quantity, String? unit}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final trimmedUnit = unit?.trim();

    final updates = <String, dynamic>{'name': trimmedName, 'unit': (trimmedUnit == null || trimmedUnit.isEmpty) ? null : trimmedUnit};
    if (quantity != null) updates['quantity'] = quantity;

    await _items(listId).doc(itemId).update(updates);
  }

  Future<void> setBought({required String listId, required String itemId, required bool bought}) async {
    final batch = _firestore.batch();

    batch.update(_items(listId).doc(itemId), {'is_bought': bought, 'bought_at': bought ? FieldValue.serverTimestamp() : null});

    batch.update(_lists.doc(listId), {'bought_count': FieldValue.increment(bought ? 1 : -1)});

    await batch.commit();
  }

  Future<void> deleteItem({required String listId, required String itemId, required bool wasBought}) async {
    final batch = _firestore.batch();

    batch.delete(_items(listId).doc(itemId));
    batch.update(_lists.doc(listId), {
      'item_count': FieldValue.increment(-1),
      if (wasBought) 'bought_count': FieldValue.increment(-1),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> renameList({required String listId, required String name, required List<String> memberUids}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final batch = _firestore.batch();
    batch.update(_lists.doc(listId), {'name': trimmedName});

    for (final uid in memberUids) {
      batch.update(_memberships(uid).doc(listId), {'name': trimmedName});
    }

    await batch.commit();
  }

  Future<void> deleteList({required String listId, required List<String> memberUids}) async {
    // Firestore doesn't auto-delete subcollections; delete items first
    final itemsSnap = await _items(listId).get();
    final batch = _firestore.batch();

    for (final doc in itemsSnap.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_lists.doc(listId));

    for (final uid in memberUids) {
      batch.delete(_memberships(uid).doc(listId));
    }

    await batch.commit();
  }

  Future<void> leaveList({required String uid, required String listId}) async {
    final listDoc = await _lists.doc(listId).get();
    final members = (listDoc.data()?['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().where((m) => m['user_id'] != uid).toList();

    final batch = _firestore.batch();
    batch.update(_lists.doc(listId), {'members': members});
    batch.delete(_memberships(uid).doc(listId));
    await batch.commit();
  }

  Future<void> removeMember({required String listId, required String memberUid}) async {
    final listDoc = await _lists.doc(listId).get();
    final members = (listDoc.data()?['members'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((m) => m['user_id'] != memberUid)
        .toList();

    final batch = _firestore.batch();
    batch.update(_lists.doc(listId), {'members': members});
    batch.delete(_memberships(memberUid).doc(listId));
    await batch.commit();
  }

  Future<void> transferOwnership({required String listId, required String currentOwnerUid, required String newOwnerUid}) async {
    final listDoc = await _lists.doc(listId).get();
    final members = (listDoc.data()?['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().map((m) {
      if (m['user_id'] == currentOwnerUid) return {...m, 'role': 'member'};
      if (m['user_id'] == newOwnerUid) return {...m, 'role': 'owner'};
      return m;
    }).toList();

    await _lists.doc(listId).update({'owner_id': newOwnerUid, 'members': members});
  }

  Future<void> inviteByEmail({
    required String listId,
    required String listName,
    required String invitedByUid,
    required String invitedByName,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Verify the email belongs to a registered user
    final userQuery = await _firestore.collection('users').where('email', isEqualTo: normalizedEmail).limit(1).get();
    if (userQuery.docs.isEmpty) {
      throw Exception('No user with that email address was found');
    }
    final invitedUid = userQuery.docs.first.id;

    // Check member limit and whether already a member
    final listDoc = await _lists.doc(listId).get();
    final members = (listDoc.data()?['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (members.any((m) => m['user_id'] == invitedUid)) {
      throw Exception('User is already a member of this list');
    }

    if (members.length >= 5) {
      throw Exception('This list has reached the maximum of 5 members');
    }

    final invitorLists = await getUserLists(invitedByUid);
    final invitorSharedCount = invitorLists.where((l) => l.members.length > 1).length;
    if (invitorSharedCount >= maxNumberOfSharedShoppingLists) {
      throw Exception('You have reached the maximum of $maxNumberOfSharedShoppingLists shared shopping lists');
    }

    // Check for existing pending invitation
    final existing = await _invitations.where('list_id', isEqualTo: listId).where('invited_email', isEqualTo: normalizedEmail).limit(1).get();

    if (existing.docs.isNotEmpty) {
      throw Exception('User has already been invited to this list');
    }

    final now = Timestamp.now();
    await _invitations.add({
      'list_id': listId,
      'list_name': listName,
      'invited_uid': invitedUid,
      'invited_email': normalizedEmail,
      'invited_by_user_id': invitedByUid,
      'invited_by_name': invitedByName,
      'status': 'pending',
      'sent_at': now,
      'responded_at': null,
      'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
  }

  // All docs in the collection are pending — completed ones are deleted
  Stream<List<ShoppingListInvitation>> watchPendingInvitations(String email) {
    return _invitations
        .where('invited_email', isEqualTo: email.toLowerCase())
        .snapshots()
        .map((snap) => snap.docs.map(ShoppingListInvitation.fromDoc).toList());
  }

  Stream<List<ShoppingListInvitation>> watchListPendingInvitations(String listId) {
    return _invitations.where('list_id', isEqualTo: listId).snapshots().map((snap) => snap.docs.map(ShoppingListInvitation.fromDoc).toList());
  }

  Future<void> acceptInvitation({
    required String invitationId,
    required String listId,
    required String listName,
    required String uid,
    required String userName,
  }) async {
    final userLists = await getUserLists(uid);
    if (userLists.length >= maxNumberOfShoppingLists) {
      throw Exception('You have reached the maximum of $maxNumberOfShoppingLists shopping lists');
    }

    final sharedCount = userLists.where((l) => l.members.length > 1).length;
    if (sharedCount >= maxNumberOfSharedShoppingLists) {
      throw Exception('You have reached the maximum of $maxNumberOfSharedShoppingLists shared shopping lists');
    }

    final now = Timestamp.now();
    final batch = _firestore.batch();

    batch.delete(_invitations.doc(invitationId));

    // arrayUnion appends the new member without needing to read the list first,
    // which would fail because the accepting user is not yet a member.
    batch.update(_lists.doc(listId), {
      'members': FieldValue.arrayUnion([
        {'user_id': uid, 'name': userName, 'joined_at': now, 'role': 'member'},
      ]),
    });

    batch.set(_memberships(uid).doc(listId), {'list_id': listId, 'name': listName, 'joined_at': now});

    await batch.commit();
  }

  Future<List<ShoppingList>> getUserLists(String uid) async {
    final membershipSnap = await _memberships(uid).get();
    if (membershipSnap.docs.isEmpty) return [];
    final docs = await Future.wait(membershipSnap.docs.map((m) => _lists.doc(m.id).get()));
    return docs.where((d) => d.exists).map(ShoppingList.fromDoc).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<String?> getPrimaryListId(String uid) async {
    final snap = await _memberships(uid).orderBy('joined_at').limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> declineInvitation(String invitationId) async {
    await _invitations.doc(invitationId).delete();
  }

  Future<List<ShoppingListInvitation>> getListPendingInvitations(String listId) async {
    final snap = await _invitations.where('list_id', isEqualTo: listId).get();
    return snap.docs.map(ShoppingListInvitation.fromDoc).toList();
  }

  Future<void> cancelInvitation(String invitationId) async {
    await _invitations.doc(invitationId).delete();
  }
}
