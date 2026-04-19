import 'package:cloud_firestore/cloud_firestore.dart';

import '../../deals/data/catalog_deal_item.dart';
import '../../../shared/repository/catalog_deals_repository.dart';
import '../../../shared/services/deal_text_matcher_service.dart';
import 'home_deal_card_item.dart';

class PersonalizedDealsRepository {
  PersonalizedDealsRepository({
    FirebaseFirestore? firestore,
    CatalogDealsRepository? catalogDealsRepository,
    DealTextMatcherService? dealTextMatcherService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _catalogDealsRepository = catalogDealsRepository ?? CatalogDealsRepository(firestore: firestore),
       _dealTextMatcherService = dealTextMatcherService ?? const DealTextMatcherService();

  final FirebaseFirestore _firestore;
  final CatalogDealsRepository _catalogDealsRepository;
  final DealTextMatcherService _dealTextMatcherService;

  CollectionReference<Map<String, dynamic>> _shoppingListItems(String uid) => _firestore.collection('users').doc(uid).collection('shopping_list');
  CollectionReference<Map<String, dynamic>> _commonProducts(String uid) => _firestore.collection('users').doc(uid).collection('common_products');

  Stream<List<PersonalizedDealCardItem>> watchShoppingListOnSale(String uid, {int limit = 10}) {
    return _shoppingListItems(uid).snapshots().asyncMap((snapshot) async {
      final shoppingListTexts = _extractShoppingListTexts(snapshot);
      return _matchDealsForTexts(shoppingListTexts, limit: limit);
    });
  }

  Stream<List<PersonalizedDealCardItem>> watchCommonBoughtProductsOnSale(String uid, {int limit = 10}) {
    return _commonProducts(uid).snapshots().asyncMap((snapshot) async {
      final commonProductTexts = _extractCommonProductTexts(snapshot);
      return _matchDealsForTexts(commonProductTexts, limit: limit);
    });
  }

  Stream<List<PersonalizedDealCardItem>> watchFromSpendingHabitsOnSale(String uid, {int limit = 10}) {
    return watchCommonBoughtProductsOnSale(uid, limit: limit);
  }

  Set<String> _extractShoppingListTexts(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.expand((doc) {
      final data = doc.data();
      final bought = data['bought'] as bool? ?? false;
      if (bought) {
        return const <String>[];
      }

      final values = <String>[];

      final name = (data['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) values.add(name);

      final brand = (data['brand'] as String?)?.trim();
      if (brand != null && brand.isNotEmpty) values.add(brand);

      if (name != null && name.isNotEmpty && brand != null && brand.isNotEmpty) {
        values.add('$brand $name');
        values.add('$name $brand');
      }

      return values;
    }).toSet();
  }

  Set<String> _extractCommonProductTexts(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.expand((doc) {
      final data = doc.data();
      final values = <String>[];

      final name = (data['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) values.add(name);

      final brand = (data['brand'] as String?)?.trim();
      if (brand != null && brand.isNotEmpty) values.add(brand);

      if (name != null && name.isNotEmpty && brand != null && brand.isNotEmpty) {
        values.add('$brand $name');
        values.add('$name $brand');
      }

      return values;
    }).toSet();
  }

  Future<List<PersonalizedDealCardItem>> _matchDealsForTexts(Set<String> sourceTexts, {required int limit}) async {
    if (sourceTexts.isEmpty) return const <PersonalizedDealCardItem>[];

    final activeDeals = await _catalogDealsRepository.watchActiveCatalogDeals(fetchLimit: 400).first;
    final matchedDeals = _dealTextMatcherService.matchDeals(shoppingListTexts: sourceTexts, deals: activeDeals);
    final matches = matchedDeals.map(_catalogToCardItem).toList(growable: false);

    if (matches.length <= limit) return matches;
    return matches.take(limit).toList(growable: false);
  }

  PersonalizedDealCardItem _catalogToCardItem(CatalogDealItem deal) {
    return PersonalizedDealCardItem(
      id: deal.productId,
      title: deal.title,
      storeName: deal.storeName,
      currentPriceCents: deal.salePriceCents,
      previousPriceCents: deal.originalPriceCents,
      discountPercent: deal.discountPercent,
      imageUrl: deal.imageUrl,
      validUntil: deal.validUntil,
    );
  }
}
