import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/deals/data/catalog_deal_item.dart';
import '../repository/catalog_deals_repository.dart';

final catalogDealsRepositoryProvider = Provider<CatalogDealsRepository>((ref) {
  return CatalogDealsRepository();
});

final allCatalogDealsProvider = StreamProvider<List<CatalogDealItem>>((ref) {
  return ref.watch(catalogDealsRepositoryProvider).watchActiveCatalogDeals();
});

final bestCatalogDealsProvider = StreamProvider<List<CatalogDealItem>>((ref) {
  return ref.watch(catalogDealsRepositoryProvider).watchBestDealsThisWeek();
});
