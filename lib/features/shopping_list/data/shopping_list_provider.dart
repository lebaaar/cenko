import 'package:cenko/features/shopping_list/data/shared_shopping_list_repository.dart';
import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_invitation.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedShoppingListRepositoryProvider = Provider<SharedShoppingListRepository>((ref) {
  return SharedShoppingListRepository();
});

final userShoppingListsProvider = StreamProvider.family<List<ShoppingList>, String>((ref, uid) {
  ref.watch(internetStatusProvider);
  return ref.watch(sharedShoppingListRepositoryProvider).watchUserLists(uid);
});

final shoppingListProvider = StreamProvider.family<ShoppingList?, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.watch(sharedShoppingListRepositoryProvider).watchList(listId);
});

final shoppingListItemsProvider = StreamProvider.family<List<ShoppingListItem>, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.watch(sharedShoppingListRepositoryProvider).watchItems(listId);
});

final pendingInvitationsProvider = StreamProvider.family<List<ShoppingListInvitation>, String>((ref, email) {
  ref.watch(internetStatusProvider);
  return ref.watch(sharedShoppingListRepositoryProvider).watchPendingInvitations(email);
});

final listPendingInvitationsProvider = StreamProvider.family<List<ShoppingListInvitation>, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.watch(sharedShoppingListRepositoryProvider).watchListPendingInvitations(listId);
});

/// The ID of the user's most-recently-updated list, or null if they have none.
final primaryListIdProvider = Provider.family<String?, String>((ref, uid) {
  final lists = ref.watch(userShoppingListsProvider(uid)).asData?.value;
  if (lists == null || lists.isEmpty) return null;
  return lists.first.id;
});
