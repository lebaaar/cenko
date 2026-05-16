import 'dart:async';

import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/features/home/data/home_deal_card_item.dart';
import 'package:cenko/shared/repository/catalog_deals_repository.dart';
import 'package:cenko/shared/services/deal_text_matcher_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  StreamSubscription<List<CatalogDealItem>>? _activeDealsSubscription;
  final Completer<void> _activeDealsReady = Completer<void>();
  List<CatalogDealItem> _activeDealsCache = const <CatalogDealItem>[];

  CollectionReference<Map<String, dynamic>> _memberships(String uid) =>
      _firestore.collection('users').doc(uid).collection('shopping_lists_memberships');
  CollectionReference<Map<String, dynamic>> _commonProducts(String uid) => _firestore.collection('users').doc(uid).collection('common_products');

  void _ensureActiveDealsSubscription() {
    if (_activeDealsSubscription != null) {
      return;
    }

    _activeDealsSubscription = _catalogDealsRepository
        .watchActiveCatalogDeals(fetchLimit: 400)
        .listen(
          (deals) {
            _activeDealsCache = deals;
            if (!_activeDealsReady.isCompleted) {
              _activeDealsReady.complete();
            }
          },
          onError: (_) {
            if (!_activeDealsReady.isCompleted) {
              _activeDealsReady.complete();
            }
          },
        );
  }

  Future<List<CatalogDealItem>> _getActiveDeals() async {
    _ensureActiveDealsSubscription();

    if (_activeDealsCache.isNotEmpty) {
      return _activeDealsCache;
    }

    await _activeDealsReady.future;
    return _activeDealsCache;
  }

  Stream<List<PersonalizedDealCardItem>> watchShoppingListOnSale(String uid, {int limit = 10}) {
    _ensureActiveDealsSubscription();
    return _memberships(uid).snapshots().asyncMap((membershipSnap) async {
      final listIds = membershipSnap.docs.map((d) => d.id).toList();
      if (listIds.isEmpty) return <PersonalizedDealCardItem>[];

      final snapshots = await Future.wait(listIds.map((id) => _firestore.collection('shopping_lists').doc(id).collection('items').get()));

      final texts = <String>{};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['is_bought'] as bool? ?? false) continue;
          final name = (data['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) texts.add(name);
        }
      }

      return _matchDealsForTexts(texts, limit: limit);
    });
  }

  Stream<List<PersonalizedDealCardItem>> watchCommonBoughtProductsOnSale(String uid, {int limit = 10}) {
    _ensureActiveDealsSubscription();
    return _commonProducts(uid).snapshots().asyncMap((snapshot) async {
      final commonProductTexts = _extractCommonProductTexts(snapshot);
      return _matchDealsForTexts(commonProductTexts, limit: limit);
    });
  }

  Stream<List<PersonalizedDealCardItem>> watchFromSpendingHabitsOnSale(String uid, {int limit = 10}) {
    return watchCommonBoughtProductsOnSale(uid, limit: limit);
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

    final activeDeals = await _getActiveDeals();
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
