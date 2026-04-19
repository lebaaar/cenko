import 'package:cenko/core/utils/price_util.dart';
import 'package:flutter/material.dart';

import '../../features/home/data/home_deal_card_item.dart';

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
          height: 80,
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DealImage(imageUrl: item.imageUrl),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(item.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
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
    );
  }
}

class _DealImage extends StatelessWidget {
  const _DealImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 78,
      color: colorScheme.surfaceContainer,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.shopping_bag_outlined, color: colorScheme.primary),
            )
          : Icon(Icons.shopping_bag_outlined, color: colorScheme.primary),
    );
  }
}
