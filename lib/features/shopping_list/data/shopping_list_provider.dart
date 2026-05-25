import 'package:cenko/features/shopping_list/data/category.dart';
import 'package:cenko/features/shopping_list/data/shared_shopping_list_repository.dart';
import 'package:cenko/features/shopping_list/data/shopping_list.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_invitation.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedShoppingListRepositoryProvider = Provider<SharedShoppingListRepository>((ref) {
  return SharedShoppingListRepository();
});

/// Category list. autoDispose so a failed fetch is retried when the widget re-subscribes
/// (e.g. after the user navigates away and back on reconnect).
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  ref.watch(internetStatusProvider); // re-fetch on network reconnect
  return ref.read(sharedShoppingListRepositoryProvider).getCategories();
});

final userShoppingListsProvider = FutureProvider.autoDispose.family<List<ShoppingList>, String>((ref, uid) {
  ref.watch(internetStatusProvider); // re-fetch on network reconnect
  return ref.read(sharedShoppingListRepositoryProvider).getUserLists(uid);
});

final shoppingListProvider = FutureProvider.autoDispose.family<ShoppingList?, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.read(sharedShoppingListRepositoryProvider).getList(listId);
});

final shoppingListItemsProvider = FutureProvider.autoDispose.family<List<ShoppingListItem>, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.read(sharedShoppingListRepositoryProvider).getItems(listId);
});

/// Pending invitations for a user (shown on the shopping list screen).
final pendingInvitationsProvider = FutureProvider.autoDispose.family<List<ShoppingListInvitation>, String>((ref, userId) {
  ref.watch(internetStatusProvider);
  return ref.read(sharedShoppingListRepositoryProvider).getPendingInvitations(userId);
});

/// Pending invitations for a specific list (shown in manage members dialog).
final listPendingInvitationsProvider = FutureProvider.autoDispose.family<List<ShoppingListInvitation>, String>((ref, listId) {
  ref.watch(internetStatusProvider);
  return ref.read(sharedShoppingListRepositoryProvider).getListPendingInvitations(listId);
});

/// The ID of the user's first-joined list, or null if they have none.
final primaryListIdProvider = Provider.autoDispose.family<String?, String>((ref, uid) {
  final lists = ref.watch(userShoppingListsProvider(uid)).asData?.value;
  if (lists == null || lists.isEmpty) return null;
  return lists.first.id;
});
