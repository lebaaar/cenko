import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shopping_list_item.dart';
import 'shopping_list_repository.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  return ShoppingListRepository();
});

final shoppingListItemsProvider = StreamProvider.family<List<ShoppingListItem>, String>((ref, uid) {
  return ref.watch(shoppingListRepositoryProvider).watchItems(uid);
});
