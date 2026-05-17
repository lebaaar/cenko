import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/core/utils/store_util.dart';
import 'package:cenko/features/home/data/home_deal_card_item.dart';
import 'package:flutter/material.dart';

class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.item, this.onTap});

  final PersonalizedDealCardItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showDiscount = (item.discountPercent ?? 0) > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88, maxHeight: 90),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DealImage(imageUrl: item.imageUrl, storeName: item.storeName),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            storeDisplayName(item.storeName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(formatCents(item.currentPriceCents), style: Theme.of(context).textTheme.titleMedium),
                              if (showDiscount && item.previousPriceCents != null)
                                Text(
                                  formatCents(item.previousPriceCents!),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                                ),
                              if (showDiscount)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '-${item.discountPercent}%',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DealImage extends StatelessWidget {
  const _DealImage({this.imageUrl, required this.storeName});

  final String? imageUrl;
  final String storeName;

  Widget _fallbackWidget(ColorScheme colorScheme) {
    final fallbackAsset = storeLogoAsset(storeName);
    if (fallbackAsset != null) {
      return Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.shopping_bag_outlined, color: colorScheme.primary),
      );
    }
    return Icon(Icons.shopping_bag_outlined, color: colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 82,
      constraints: const BoxConstraints(minHeight: 88, maxHeight: 110),
      color: colorScheme.surfaceContainer,
      child: hasImage
          ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackWidget(colorScheme))
          : _fallbackWidget(colorScheme),
    );
  }
}
