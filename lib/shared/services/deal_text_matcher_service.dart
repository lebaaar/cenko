import 'package:cenko/features/deals/data/catalog_deal_item.dart';

class DealTextMatcherService {
  const DealTextMatcherService();

  List<CatalogDealItem> matchDeals({required Iterable<String> shoppingListTexts, required Iterable<CatalogDealItem> deals, double minScore = 0.45}) {
    final preparedUserTexts = shoppingListTexts.map(_prepareText).where((text) => text.normalized.isNotEmpty).toSet();

    if (preparedUserTexts.isEmpty) return const <CatalogDealItem>[];

    final scored = <_ScoredDeal>[];
    for (final deal in deals) {
      final dealCandidates = _dealCandidates(deal);
      if (dealCandidates.isEmpty) {
        continue;
      }

      var bestScore = 0.0;
      for (final userText in preparedUserTexts) {
        for (final dealText in dealCandidates) {
          final score = _similarity(userText, dealText);
          if (score > bestScore) {
            bestScore = score;
          }
          if (bestScore >= 0.99) {
            break;
          }
        }
        if (bestScore >= 0.99) {
          break;
        }
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

  Set<_PreparedText> _dealCandidates(CatalogDealItem deal) {
    final candidates = <_PreparedText>{
      _prepareText(deal.title),
      _prepareText('${deal.brand ?? ''} ${deal.title}'),
      _prepareText('${deal.title} ${deal.brand ?? ''}'),
    };

    return candidates.where((candidate) => candidate.normalized.isNotEmpty).toSet();
  }

  _PreparedText _prepareText(String text) {
    var normalized = text.toLowerCase();
    normalized = _foldDiacritics(normalized);
    normalized = normalized
        .replaceAllMapped(RegExp(r'([a-z])([0-9])'), (match) => '${match.group(1)} ${match.group(2)}')
        .replaceAllMapped(RegExp(r'([0-9])([a-z])'), (match) => '${match.group(1)} ${match.group(2)}')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return const _PreparedText(normalized: '', compact: '', tokens: <String>{});
    }

    final tokens = normalized.split(' ').where((token) => token.length > 1).toSet();
    final compact = normalized.replaceAll(' ', '');

    return _PreparedText(normalized: normalized, compact: compact, tokens: tokens);
  }

  String _foldDiacritics(String text) {
    const replacements = <String, String>{
      'č': 'c',
      'ć': 'c',
      'š': 's',
      'đ': 'd',
      'ž': 'z',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ñ': 'n',
    };

    final output = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      output.write(replacements[ch] ?? ch);
    }
    return output.toString();
  }

  double _similarity(_PreparedText left, _PreparedText right) {
    if (left.normalized.isEmpty || right.normalized.isEmpty) {
      return 0.0;
    }

    if (left.normalized == right.normalized) return 1.0;
    if (left.compact == right.compact) return 0.98;
    if (left.compact.contains(right.compact) || right.compact.contains(left.compact)) return 0.94;
    if (left.normalized.contains(right.normalized) || right.normalized.contains(left.normalized)) return 0.9;

    final leftTokens = left.tokens;
    final rightTokens = right.tokens;
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0.0;

    final intersection = leftTokens.intersection(rightTokens).length.toDouble();
    final union = leftTokens.union(rightTokens).length.toDouble();
    final jaccard = union == 0 ? 0.0 : intersection / union;

    final fuzzyOverlap = _fuzzyTokenOverlap(leftTokens, rightTokens);
    final compactBoost = _compactTokenMatchBoost(left, right);

    final blended = (jaccard * 0.55) + (fuzzyOverlap * 0.35) + compactBoost;
    return blended.clamp(0.0, 1.0);
  }

  double _fuzzyTokenOverlap(Set<String> leftTokens, Set<String> rightTokens) {
    var matches = 0;
    for (final left in leftTokens) {
      var found = false;
      for (final right in rightTokens) {
        if (left == right) {
          found = true;
          break;
        }

        if (left.length >= 3 && right.length >= 3 && (left.contains(right) || right.contains(left))) {
          found = true;
          break;
        }
      }
      if (found) {
        matches += 1;
      }
    }

    final denominator = leftTokens.length > rightTokens.length ? leftTokens.length : rightTokens.length;
    if (denominator == 0) {
      return 0.0;
    }

    return matches / denominator;
  }

  double _compactTokenMatchBoost(_PreparedText left, _PreparedText right) {
    for (final leftToken in left.tokens) {
      if (leftToken.length < 4) {
        continue;
      }

      if (right.compact.contains(leftToken)) {
        return 0.08;
      }
    }

    for (final rightToken in right.tokens) {
      if (rightToken.length < 4) {
        continue;
      }

      if (left.compact.contains(rightToken)) {
        return 0.08;
      }
    }

    return 0.0;
  }
}

class _PreparedText {
  const _PreparedText({required this.normalized, required this.compact, required this.tokens});

  final String normalized;
  final String compact;
  final Set<String> tokens;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PreparedText && other.normalized == normalized;
  }

  @override
  int get hashCode => normalized.hashCode;
}

class _ScoredDeal {
  const _ScoredDeal({required this.deal, required this.score});

  final CatalogDealItem deal;
  final double score;
}
