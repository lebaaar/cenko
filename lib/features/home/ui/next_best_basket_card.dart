import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/features/home/data/next_best_basket_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NextBestBasketCard extends StatelessWidget {
  const NextBestBasketCard({super.key, required this.summaryAsync});

  final AsyncValue<NextBestBasketSummary?> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return summaryAsync.when(
      loading: () => _BasketCardShell(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        ),
      ),
      error: (error, _) => _BasketCardShell(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text('Could not build basket recommendation: $error', style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
      data: (summary) {
        if (summary == null) {
          return _BasketCardShell(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next best basket', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Add a few shopping list items to see which store is cheapest for your basket.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.go('/list'),
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Build a list'),
                  ),
                ],
              ),
            ),
          );
        }

        final coverage = summary.sourceItemCount == 0 ? 0.0 : summary.matchedItemCount / summary.sourceItemCount;

        return _BasketCardShell(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.shopping_cart_checkout_rounded, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next best basket', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Best store today: ${summary.recommendedStoreName}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      '${(coverage * 100).round()}% matched',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBlock(label: 'Estimated total', value: formatCents(summary.estimatedTotalCents)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricBlock(label: 'Estimated savings', value: formatCents(summary.estimatedSavingsCents)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Matched ${summary.matchedItemCount} of ${summary.sourceItemCount} list items to live deals.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (summary.topItems.isNotEmpty) ...[
                  for (final item in summary.topItems) ...[_BasketItemRow(item: item), const SizedBox(height: 8)],
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.go('/deals'),
                    icon: const Icon(Icons.local_offer_rounded),
                    label: const Text('View matching deals'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BasketCardShell extends StatelessWidget {
  const _BasketCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.surfaceContainerHigh, colorScheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BasketItemRow extends StatelessWidget {
  const _BasketItemRow({required this.item});

  final BasketRecommendationItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: colorScheme.surface.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  item.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCents(item.currentPriceCents), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              if ((item.discountPercent ?? 0) > 0)
                Text(
                  '-${item.discountPercent}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
