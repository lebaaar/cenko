import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/features/home/data/home_deal_card_item.dart';
import 'package:cenko/shared/repository/catalog_deals_repository.dart';
import 'package:cenko/shared/services/deal_text_matcher_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalizedDealsRepository {
  PersonalizedDealsRepository({
    CatalogDealsRepository? catalogDealsRepository,
    DealTextMatcherService? dealTextMatcherService,
  }) : _catalogDealsRepository = catalogDealsRepository ?? CatalogDealsRepository(),
       _dealTextMatcherService = dealTextMatcherService ?? const DealTextMatcherService();

  final _client = Supabase.instance.client;
  final CatalogDealsRepository _catalogDealsRepository;
  final DealTextMatcherService _dealTextMatcherService;

  /// Fetches unbought shopping list item names and matches them against active deals.
  Future<List<PersonalizedDealCardItem>> fetchShoppingListOnSale(String uid, {int limit = 10}) async {
    final memberRows = await _client
        .from('shopping_list_member')
        .select('shopping_list_id')
        .eq('user_id', uid);
    if ((memberRows as List).isEmpty) return const [];
    final listIds = memberRows.map((r) => r['shopping_list_id']).toList();
    final itemRows = await _client
        .from('shopping_list_item')
        .select('name')
        .inFilter('shopping_list_id', listIds)
        .eq('is_bought', false);
    final texts = (itemRows as List)
        .map((r) => (r['name'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
    return _matchDealsForTexts(texts, limit: limit);
  }

  Future<List<PersonalizedDealCardItem>> _matchDealsForTexts(Set<String> sourceTexts, {required int limit}) async {
    if (sourceTexts.isEmpty) return const [];
    final activeDeals = await _catalogDealsRepository.watchActiveCatalogDeals(fetchLimit: 400).first;
    final matchedDeals = _dealTextMatcherService.matchDeals(shoppingListTexts: sourceTexts, deals: activeDeals);
    final matches = matchedDeals.map(_catalogToCardItem).toList(growable: false);
    if (matches.length <= limit) return matches;
    return matches.take(limit).toList(growable: false);
  }

  PersonalizedDealCardItem _catalogToCardItem(CatalogDealItem deal) {
    return PersonalizedDealCardItem(
      id: deal.productId,
      dealId: deal.id,
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
