import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:cenko/shared/repository/catalog_deals_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogDealsRepositoryProvider = Provider<CatalogDealsRepository>((ref) {
  return CatalogDealsRepository();
});

final allCatalogDealsProvider = StreamProvider<List<CatalogDealItem>>((ref) {
  ref.watch(internetStatusProvider);
  return ref.watch(catalogDealsRepositoryProvider).watchActiveCatalogDeals();
});

final bestCatalogDealsProvider = StreamProvider<List<CatalogDealItem>>((ref) {
  ref.watch(internetStatusProvider);
  return ref.watch(catalogDealsRepositoryProvider).watchBestDealsThisWeek();
});
