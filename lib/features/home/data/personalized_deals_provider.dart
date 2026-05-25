import 'package:cenko/features/home/data/home_deal_card_item.dart';
import 'package:cenko/features/home/data/personalized_deals_repository.dart';
import 'package:cenko/shared/providers/catalog_deals_provider.dart';
import 'package:cenko/shared/providers/deal_text_matcher_provider.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalizedDealsRepositoryProvider = Provider<PersonalizedDealsRepository>((ref) {
  return PersonalizedDealsRepository(
    catalogDealsRepository: ref.watch(catalogDealsRepositoryProvider),
    dealTextMatcherService: ref.watch(dealTextMatcherServiceProvider),
  );
});

final shoppingListOnSaleProvider = FutureProvider.autoDispose.family<List<PersonalizedDealCardItem>, String>((ref, uid) {
  ref.watch(internetStatusProvider);
  return ref.read(personalizedDealsRepositoryProvider).fetchShoppingListOnSale(uid);
});

