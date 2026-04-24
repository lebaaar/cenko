import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_shopping_list_repository.dart';
import 'shopping_list.dart';
import 'shopping_list_invitation.dart';
import 'shopping_list_item.dart';

final sharedShoppingListRepositoryProvider = Provider<SharedShoppingListRepository>((ref) {
  return SharedShoppingListRepository();
});

final userShoppingListsProvider = StreamProvider.family<List<ShoppingList>, String>((ref, uid) {
  return ref.watch(sharedShoppingListRepositoryProvider).watchUserLists(uid);
});

final shoppingListProvider = StreamProvider.family<ShoppingList?, String>((ref, listId) {
  return ref.watch(sharedShoppingListRepositoryProvider).watchList(listId);
});

final shoppingListItemsProvider = StreamProvider.family<List<ShoppingListItem>, String>((ref, listId) {
  return ref.watch(sharedShoppingListRepositoryProvider).watchItems(listId);
});

final pendingInvitationsProvider = StreamProvider.family<List<ShoppingListInvitation>, String>((ref, uid) {
  return ref.watch(sharedShoppingListRepositoryProvider).watchPendingInvitations(uid);
});

/// The ID of the user's most-recently-updated list, or null if they have none.
final primaryListIdProvider = Provider.family<String?, String>((ref, uid) {
  final lists = ref.watch(userShoppingListsProvider(uid)).asData?.value;
  if (lists == null || lists.isEmpty) return null;
  return lists.first.id;
});
