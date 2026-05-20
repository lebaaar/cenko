import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/core/utils/store_util.dart';
import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class DealsGridCard extends StatelessWidget {
  // constructors
  const DealsGridCard.fromCatalog({
    super.key,
    required this.deal,
    this.onTap,
    this.onAddToShoppingList,
    this.isAddingToShoppingList = false,
    this.isAlreadyOnShoppingList = false,
  });

  final CatalogDealItem deal;
  final VoidCallback? onTap;
  final VoidCallback? onAddToShoppingList;
  final bool isAddingToShoppingList;
  final bool isAlreadyOnShoppingList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(deal.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 3),
                            Text(
                              storeDisplayName(deal.storeName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatCents(deal.salePriceCents),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if ((discount ?? 0) > 0) const SizedBox(width: 8),
                                if ((discount ?? 0) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '-$discount%',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                              ],
                            ),
                            if (deal.originalPriceCents != null && (discount ?? 0) > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                formatCents(deal.originalPriceCents!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${l10n.productValidUntil} ${displayDate(deal.validUntil)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Theme(
                          data: Theme.of(context).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: FilledButton.icon(
                            onPressed: (isAddingToShoppingList || isAlreadyOnShoppingList) ? null : onAddToShoppingList,
                            icon: Icon(isAlreadyOnShoppingList ? Icons.check_circle_rounded : Icons.playlist_add_rounded, size: 18),
                            label: Text(isAlreadyOnShoppingList ? l10n.dealOnList : l10n.addToList, maxLines: 1, overflow: TextOverflow.ellipsis),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(34),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: Colors.white,
                              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
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

  Widget _fallbackWidget(ColorScheme colorScheme) {
    final fallbackAsset = storeLogoAsset(storeName);
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
