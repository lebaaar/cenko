import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogDealsRepository {
  final _client = Supabase.instance.client;

  Stream<List<CatalogDealItem>> watchActiveCatalogDeals({int fetchLimit = 400}) async* {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('product')
        .select('*, store:store_id(name)')
        .or('valid_to.is.null,valid_to.gte.$now')
        .order('valid_to', ascending: true)
        .limit(fetchLimit);
    yield (rows as List)
        .map((r) => CatalogDealItem.fromMap(r as Map<String, dynamic>))
        .where((d) => d.isActive)
        .toList(growable: false);
  }

  Stream<List<CatalogDealItem>> watchBestDealsThisWeek({int limit = 10}) {
    return watchActiveCatalogDeals(fetchLimit: 400).map((deals) {
      final sorted = [...deals]
        ..sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
      if (sorted.length <= limit) return sorted;
      return sorted.take(limit).toList(growable: false);
    });
  }
}
