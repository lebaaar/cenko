import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/catalog_deals_provider.dart';
import '../../../shared/providers/deal_text_matcher_provider.dart';
import 'home_deal_card_item.dart';
import 'personalized_deals_repository.dart';

final personalizedDealsRepositoryProvider = Provider<PersonalizedDealsRepository>((ref) {
  return PersonalizedDealsRepository(
    catalogDealsRepository: ref.watch(catalogDealsRepositoryProvider),
    dealTextMatcherService: ref.watch(dealTextMatcherServiceProvider),
  );
});

final shoppingListOnSaleProvider = StreamProvider.family<List<PersonalizedDealCardItem>, String>((ref, uid) {
  return ref.watch(personalizedDealsRepositoryProvider).watchShoppingListOnSale(uid);
});

final spendingHabitsOnSaleProvider = StreamProvider.family<List<PersonalizedDealCardItem>, String>((ref, uid) {
  return ref.watch(personalizedDealsRepositoryProvider).watchFromSpendingHabitsOnSale(uid);
});
