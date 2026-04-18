import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/deals/data/catalog_deal_item.dart';

class CatalogDealsRepository {
  CatalogDealsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _catalogProducts => _firestore.collection('catalog_products');

  Stream<List<CatalogDealItem>> watchActiveCatalogDeals({int fetchLimit = 400}) {
    final now = Timestamp.fromDate(DateTime.now());
    return _catalogProducts.where('valid_until', isGreaterThanOrEqualTo: now).orderBy('valid_until').limit(fetchLimit).snapshots().map((snapshot) {
      return snapshot.docs.map(CatalogDealItem.fromFirestore).where((deal) => deal.isActive).toList(growable: false);
    });
  }

  Stream<List<CatalogDealItem>> watchBestDealsThisWeek({int limit = 10}) {
    return watchActiveCatalogDeals(fetchLimit: 400).map((deals) {
      final sorted = [...deals]..sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
      if (sorted.length <= limit) return sorted;
      return sorted.take(limit).toList(growable: false);
    });
  }
}
