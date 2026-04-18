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

enum _DealsSortOption { highestDiscount, lowestDiscount, lowestPrice, highestPrice }

class _DealsScreenState extends ConsumerState<DealsScreen> {
  static const List<String> _storeFilters = ['All', 'Mercator', 'Lidl', 'Hofer', 'Spar', 'Kaufland'];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _selectedStores = {'All'};
  RangeValues _priceRange = const RangeValues(0, 50);
  _DealsSortOption _sortOption = _DealsSortOption.highestDiscount;

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

  void _toggleStore(String store) {
    setState(() {
      if (store == 'All') {
        _selectedStores
          ..clear()
          ..add('All');
        return;
      }

      if (_selectedStores.contains('All')) {
        _selectedStores
          ..clear()
          ..add(store);
        return;
      }

      if (_selectedStores.contains(store)) {
        _selectedStores.remove(store);
        if (_selectedStores.isEmpty) {
          _selectedStores.add('All');
        }
      } else {
        _selectedStores.add(store);
      }
    });
  }

  List<CatalogDealItem> _filterAndSortDeals(List<CatalogDealItem> deals) {
    final hasStoreFilter = !_selectedStores.contains('All');

    final filtered = deals
        .where((deal) {
          final title = deal.title.toLowerCase();
          final store = deal.storeName.toLowerCase();
          final priceEuro = deal.salePriceCents / 100;

          final matchesQuery = _query.isEmpty || title.contains(_query) || store.contains(_query);
          final matchesStore = !hasStoreFilter || _selectedStores.any((selected) => store.contains(selected.toLowerCase()));
          final matchesPrice = priceEuro >= _priceRange.start && priceEuro <= _priceRange.end;

          return matchesQuery && matchesStore && matchesPrice;
        })
        .toList(growable: false);

    final sorted = [...filtered];
    switch (_sortOption) {
      case _DealsSortOption.highestDiscount:
        sorted.sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
      case _DealsSortOption.lowestDiscount:
        sorted.sort((a, b) => (a.discountPercent ?? 0).compareTo(b.discountPercent ?? 0));
      case _DealsSortOption.lowestPrice:
        sorted.sort((a, b) => a.salePriceCents.compareTo(b.salePriceCents));
      case _DealsSortOption.highestPrice:
        sorted.sort((a, b) => b.salePriceCents.compareTo(a.salePriceCents));
    }

    return sorted;
  }

  String _sortLabel(_DealsSortOption option) {
    switch (option) {
      case _DealsSortOption.highestDiscount:
        return 'Highest discount';
      case _DealsSortOption.lowestDiscount:
        return 'Lowest discount';
      case _DealsSortOption.lowestPrice:
        return 'Lowest price';
      case _DealsSortOption.highestPrice:
        return 'Highest price';
    }
  }

  String _priceRangeLabel(RangeValues range) {
    return '${range.start.round()} € - ${range.end.round()} €';
  }

  Future<void> _openPriceSheet() async {
    RangeValues draft = _priceRange;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price range', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      _priceRangeLabel(draft),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    RangeSlider(
                      values: draft,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      labels: RangeLabels('${draft.start.round()} €', '${draft.end.round()} €'),
                      onChanged: (values) {
                        setModalState(() {
                          draft = values;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                draft = const RangeValues(0, 50);
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _priceRange = draft;
                              });
                              Navigator.of(sheetContext).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSortSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text('Sort deals', style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final option in _DealsSortOption.values)
                  RadioListTile<_DealsSortOption>(
                    value: option,
                    groupValue: _sortOption,
                    title: Text(_sortLabel(option)),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _sortOption = value;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
            final filteredDeals = _filterAndSortDeals(deals);

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
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _storeFilters.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final store = _storeFilters[index];
                              final isSelected = store == 'All' ? _selectedStores.contains('All') : _selectedStores.contains(store);
                              return FilterChip(
                                label: Text(store),
                                selected: isSelected,
                                onSelected: (_) => _toggleStore(store),
                                showCheckmark: false,
                                selectedColor: Theme.of(context).colorScheme.primary,
                                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openPriceSheet,
                                icon: const Icon(Icons.euro_rounded),
                                label: const Text('Price', overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openSortSheet,
                                icon: const Icon(Icons.sort_rounded),
                                label: const Text('Sort', overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Price ${_priceRangeLabel(_priceRange)}  •  ${_sortLabel(_sortOption)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
