import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/shared/providers/catalog_deals_provider.dart';
import 'package:cenko/features/deals/ui/deals_grid_card.dart';
import 'package:cenko/shared/widgets/top_bar.dart';

class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key});

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CatalogDealItem> _filterDeals(List<CatalogDealItem> deals) {
    if (_query.isEmpty) return deals;
    return deals
        .where((deal) {
          final title = deal.title.toLowerCase();
          final store = deal.storeName.toLowerCase();
          return title.contains(_query) || store.contains(_query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final dealsAsync = ref.watch(allCatalogDealsProvider);

    return Scaffold(
      body: SafeArea(
        child: dealsAsync.when(
          loading: () => SizedBox(
            height: MediaQuery.of(context).size.height - 120,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Center(child: Text('Could not load deals: $error')),
          data: (deals) {
            final filteredDeals = _filterDeals(deals);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MainTopBar(title: 'Deals'),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                            hintText: 'Search products on sale',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                if (filteredDeals.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    sliver: SliverToBoxAdapter(
                      child: Text("This product isn't on sale in any supported stores this week.", style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final deal = filteredDeals[index];
                        return DealsGridCard.fromCatalog(deal: deal);
                      }, childCount: filteredDeals.length),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
