import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:flutter/material.dart';

import '../data/catalog_deal_item.dart';

class DealsGridCard extends StatelessWidget {
  // constructors
  const DealsGridCard.fromCatalog({super.key, required this.deal, this.onTap});

  final CatalogDealItem deal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final discount = deal.discountPercent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DealsImage(imageUrl: deal.imageUrl, storeName: deal.storeName),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deal.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(deal.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            formatCents(deal.salePriceCents),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (discount != null) const SizedBox(width: 8),
                          if (discount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                '-$discount%',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                      if (deal.originalPriceCents != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatCents(deal.originalPriceCents!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Valid until ${displayDate(deal.validUntil)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealsImage extends StatelessWidget {
  const _DealsImage({this.imageUrl, required this.storeName});

  final String? imageUrl;
  final String storeName;

  String? _fallbackAssetForStore() {
    final normalized = storeName.toLowerCase();
    final hasTus = normalized.contains('tus') || normalized.contains('tuš');
    final hasDrogerija = normalized.contains('droger');

    if (hasTus && hasDrogerija) {
      return 'assets/images/tus-drogerija.jpg';
    }
    if (hasTus) {
      return 'assets/images/tus.png';
    }
    if (normalized.contains('spar')) {
      return 'assets/images/spar.jpg';
    }
    if (normalized.contains('mercator')) {
      return 'assets/images/mercator.webp';
    }
    if (normalized.contains('lidl')) {
      return 'assets/images/lidl.png';
    }
    return null;
  }

  Widget _fallbackWidget(ColorScheme colorScheme) {
    final fallbackAsset = _fallbackAssetForStore();
    if (fallbackAsset != null) {
      return Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.local_offer_outlined, color: colorScheme.primary),
      );
    }
    return Icon(Icons.local_offer_outlined, color: colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      child: AspectRatio(
        aspectRatio: 1.28,
        child: Container(
          color: colorScheme.surfaceContainer,
          child: hasImage
              ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackWidget(colorScheme))
              : _fallbackWidget(colorScheme),
        ),
      ),
    );
  }
}
