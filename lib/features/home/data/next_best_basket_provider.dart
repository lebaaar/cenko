import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/catalog_deals_provider.dart';
import '../../../shared/providers/deal_text_matcher_provider.dart';
import '../../../shared/repository/catalog_deals_repository.dart';
import '../../../shared/services/deal_text_matcher_service.dart';
import '../../deals/data/catalog_deal_item.dart';

final nextBestBasketRepositoryProvider = Provider<NextBestBasketRepository>((ref) {
  return NextBestBasketRepository(
    catalogDealsRepository: ref.watch(catalogDealsRepositoryProvider),
    dealTextMatcherService: ref.watch(dealTextMatcherServiceProvider),
  );
});

final nextBestBasketProvider = StreamProvider.family<NextBestBasketSummary?, String>((ref, uid) {
  return ref.watch(nextBestBasketRepositoryProvider).watchNextBestBasket(uid);
});

class NextBestBasketRepository {
  NextBestBasketRepository({
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

  Stream<NextBestBasketSummary?> watchNextBestBasket(String uid) {
    return _shoppingListItems(uid).orderBy('added_at', descending: true).snapshots().asyncMap((snapshot) async {
      final sourceItems = _extractSourceItems(snapshot);
      if (sourceItems.isEmpty) {
        return null;
      }

      final activeDeals = await _catalogDealsRepository.watchActiveCatalogDeals(fetchLimit: 400).first;
      if (activeDeals.isEmpty) {
        return null;
      }

      final matchedItems = <_MatchedBasketItem>[];
      for (final sourceItem in sourceItems) {
        final matches = _dealTextMatcherService.matchDeals(shoppingListTexts: sourceItem.searchTerms, deals: activeDeals);
        if (matches.isEmpty) {
          continue;
        }

        matchedItems.add(_MatchedBasketItem.fromDeal(sourceItem, matches.first));
      }

      if (matchedItems.isEmpty) {
        return null;
      }

      final storeCandidates = <String, _StoreBasketCandidate>{};
      for (final matchedItem in matchedItems) {
        final storeName = matchedItem.storeName;
        final candidate = storeCandidates.putIfAbsent(storeName, () => _StoreBasketCandidate(storeName: storeName));
        candidate.add(matchedItem);
      }

      if (storeCandidates.isEmpty) {
        return null;
      }

      final bestCandidate = storeCandidates.values.reduce(_preferBetterCandidate);

      return NextBestBasketSummary(
        sourceItemCount: sourceItems.length,
        matchedItemCount: matchedItems.length,
        recommendedStoreName: bestCandidate.storeName,
        estimatedTotalCents: bestCandidate.totalCents,
        estimatedSavingsCents: bestCandidate.savingsCents,
        topItems: bestCandidate.previewItems,
      );
    });
  }

  List<_BasketSourceItem> _extractSourceItems(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final searchTerms = <String>{};

          final name = (data['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            searchTerms.add(name);
          }

          final brand = (data['brand'] as String?)?.trim();
          if (brand != null && brand.isNotEmpty) {
            searchTerms.add(brand);
          }

          if (name != null && name.isNotEmpty && brand != null && brand.isNotEmpty) {
            searchTerms.add('$brand $name');
            searchTerms.add('$name $brand');
          }

          return _BasketSourceItem(id: doc.id, name: name == null || name.isEmpty ? 'Unnamed item' : name, searchTerms: searchTerms);
        })
        .where((item) => item.searchTerms.isNotEmpty)
        .toList(growable: false);
  }

  _StoreBasketCandidate _preferBetterCandidate(_StoreBasketCandidate left, _StoreBasketCandidate right) {
    final coverageCmp = right.matchedItems.length.compareTo(left.matchedItems.length);
    if (coverageCmp != 0) {
      return coverageCmp > 0 ? right : left;
    }

    final savingsCmp = right.savingsCents.compareTo(left.savingsCents);
    if (savingsCmp != 0) {
      return savingsCmp > 0 ? right : left;
    }

    final totalCmp = left.totalCents.compareTo(right.totalCents);
    return totalCmp <= 0 ? left : right;
  }
}

class NextBestBasketSummary {
  const NextBestBasketSummary({
    required this.sourceItemCount,
    required this.matchedItemCount,
    required this.recommendedStoreName,
    required this.estimatedTotalCents,
    required this.estimatedSavingsCents,
    required this.topItems,
  });

  final int sourceItemCount;
  final int matchedItemCount;
  final String recommendedStoreName;
  final int estimatedTotalCents;
  final int estimatedSavingsCents;
  final List<BasketRecommendationItem> topItems;
}

class BasketRecommendationItem {
  const BasketRecommendationItem({
    required this.title,
    required this.storeName,
    required this.currentPriceCents,
    required this.previousPriceCents,
    required this.discountPercent,
    required this.imageUrl,
  });

  final String title;
  final String storeName;
  final int currentPriceCents;
  final int? previousPriceCents;
  final int? discountPercent;
  final String? imageUrl;

  int get savingsCents {
    final previous = previousPriceCents;
    if (previous == null) {
      return 0;
    }

    final diff = previous - currentPriceCents;
    return diff > 0 ? diff : 0;
  }
}

class _BasketSourceItem {
  const _BasketSourceItem({required this.id, required this.name, required this.searchTerms});

  final String id;
  final String name;
  final Set<String> searchTerms;
}

class _MatchedBasketItem {
  const _MatchedBasketItem({
    required this.sourceItemId,
    required this.title,
    required this.storeName,
    required this.currentPriceCents,
    required this.previousPriceCents,
    required this.discountPercent,
    required this.imageUrl,
  });

  final String sourceItemId;
  final String title;
  final String storeName;
  final int currentPriceCents;
  final int? previousPriceCents;
  final int? discountPercent;
  final String? imageUrl;

  factory _MatchedBasketItem.fromDeal(_BasketSourceItem sourceItem, CatalogDealItem deal) {
    return _MatchedBasketItem(
      sourceItemId: sourceItem.id,
      title: sourceItem.name,
      storeName: deal.storeName,
      currentPriceCents: deal.salePriceCents,
      previousPriceCents: deal.originalPriceCents,
      discountPercent: deal.discountPercent,
      imageUrl: deal.imageUrl,
    );
  }

  int get savingsCents {
    final previous = previousPriceCents;
    if (previous == null) {
      return 0;
    }

    final diff = previous - currentPriceCents;
    return diff > 0 ? diff : 0;
  }
}

class _StoreBasketCandidate {
  _StoreBasketCandidate({required this.storeName});

  final String storeName;
  final List<_MatchedBasketItem> matchedItems = [];

  int get totalCents => matchedItems.fold(0, (sum, item) => sum + item.currentPriceCents);

  int get savingsCents => matchedItems.fold(0, (sum, item) => sum + item.savingsCents);

  List<BasketRecommendationItem> get previewItems {
    final sorted = [...matchedItems]..sort((a, b) => b.savingsCents.compareTo(a.savingsCents));
    return sorted
        .take(3)
        .map(
          (item) => BasketRecommendationItem(
            title: item.title,
            storeName: item.storeName,
            currentPriceCents: item.currentPriceCents,
            previousPriceCents: item.previousPriceCents,
            discountPercent: item.discountPercent,
            imageUrl: item.imageUrl,
          ),
        )
        .toList(growable: false);
  }

  void add(_MatchedBasketItem item) {
    matchedItems.add(item);
  }
}
