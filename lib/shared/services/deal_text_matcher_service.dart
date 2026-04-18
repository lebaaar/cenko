import 'package:cenko/features/deals/data/catalog_deal_item.dart';

class DealTextMatcherService {
  const DealTextMatcherService();

  List<CatalogDealItem> matchDeals({required Iterable<String> shoppingListTexts, required Iterable<CatalogDealItem> deals, double minScore = 0.45}) {
    final normalizedUserTexts = shoppingListTexts.map(_normalize).where((text) => text.isNotEmpty).toSet();

    if (normalizedUserTexts.isEmpty) return const <CatalogDealItem>[];

    final scored = <_ScoredDeal>[];
    for (final deal in deals) {
      final dealText = _normalize('${deal.title} ${deal.storeName}');
      if (dealText.isEmpty) continue;

      var bestScore = 0.0;
      for (final userText in normalizedUserTexts) {
        final score = _similarity(userText, dealText);
        if (score > bestScore) bestScore = score;
        if (bestScore >= 0.99) break;
      }

      if (bestScore >= minScore) {
        scored.add(_ScoredDeal(deal: deal, score: bestScore));
      }
    }

    scored.sort((a, b) {
      final discountCmp = (b.deal.discountPercent ?? 0).compareTo(a.deal.discountPercent ?? 0);
      if (discountCmp != 0) return discountCmp;
      return b.score.compareTo(a.score);
    });

    return scored.map((entry) => entry.deal).toList(growable: false);
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _similarity(String left, String right) {
    if (left == right) return 1.0;
    if (left.contains(right) || right.contains(left)) return 0.9;

    final leftTokens = left.split(' ').where((t) => t.length > 1).toSet();
    final rightTokens = right.split(' ').where((t) => t.length > 1).toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0.0;

    final intersection = leftTokens.intersection(rightTokens).length.toDouble();
    final union = leftTokens.union(rightTokens).length.toDouble();
    if (union == 0) return 0.0;

    return intersection / union;
  }
}

class _ScoredDeal {
  const _ScoredDeal({required this.deal, required this.score});

  final CatalogDealItem deal;
  final double score;
}
