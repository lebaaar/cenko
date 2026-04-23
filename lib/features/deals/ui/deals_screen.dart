import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/shared/providers/catalog_deals_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/features/deals/ui/deals_grid_card.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/widgets/top_bar.dart';

class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

enum _DealsSortOption { highestDiscount, lowestDiscount, lowestPrice, highestPrice }

class _DealsScreenState extends ConsumerState<DealsScreen> {
  static const List<String> _storeFilters = ['All', 'Mercator', 'Spar', 'Hofer', 'Tuš', 'Tuš drogerije'];
  static const int _pageSize = 30;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _selectedStores = {'All'};
  RangeValues _priceRange = const RangeValues(0, 50);
  _DealsSortOption _sortOption = _DealsSortOption.highestDiscount;
  int _visibleCount = _pageSize;
  final Set<String> _addingDealIds = <String>{};

  String _normalizedShoppingListKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _query = _searchController.text.toLowerCase();
    }
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _visibleCount = _pageSize;
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
      _visibleCount = _pageSize;
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
    final normalizedSelectedStores = hasStoreFilter ? _selectedStores.map(_normalizedStoreKey).toSet() : const <String>{};

    final filtered = deals
        .where((deal) {
          final title = deal.title.toLowerCase();
          final store = deal.storeName.toLowerCase();
          final normalizedStore = _normalizedStoreKey(deal.storeName);
          final priceEuro = deal.salePriceCents / 100;

          final matchesQuery = _query.isEmpty || title.contains(_query) || store.contains(_query);
          final matchesStore = !hasStoreFilter || normalizedSelectedStores.contains(normalizedStore);
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

  String _normalizedStoreKey(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('š', 's')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Match known stores even when Firestore has legal suffixes or extra words.
    if (normalized.contains('tus droger')) {
      return 'tus drogerije';
    }
    if (normalized.contains('mercator')) {
      return 'mercator';
    }
    if (normalized.contains('spar')) {
      return 'spar';
    }
    if (normalized.contains('hofer')) {
      return 'hofer';
    }
    if (normalized.contains('tus')) {
      return 'tus';
    }

    return normalized;
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

  double _lineHeight(BuildContext context, TextStyle? style, {int lines = 1}) {
    final fallback = Theme.of(context).textTheme.bodyMedium;
    final resolved = style ?? fallback;
    if (resolved == null) {
      return 14 * 1.25 * lines;
    }

    final fontSize = resolved.fontSize ?? 14;
    final height = resolved.height ?? 1.25;
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(fontSize);
    return scaledFontSize * height * lines;
  }

  double _estimateDealsCardMainAxisExtent(BuildContext context, double itemWidth) {
    final textTheme = Theme.of(context).textTheme;

    final titleHeight = _lineHeight(context, textTheme.titleSmall, lines: 2);
    final storeHeight = _lineHeight(context, textTheme.bodySmall);
    final salePriceHeight = _lineHeight(context, textTheme.titleMedium);
    final discountChipHeight = _lineHeight(context, textTheme.labelSmall) + 8;
    final originalPriceHeight = _lineHeight(context, textTheme.bodySmall);
    final validUntilHeight = _lineHeight(context, textTheme.labelSmall);
    final topContentHeight =
        titleHeight +
        3 +
        storeHeight +
        6 +
        (salePriceHeight > discountChipHeight ? salePriceHeight : discountChipHeight) +
        2 +
        originalPriceHeight +
        4 +
        (validUntilHeight > 12 ? validUntilHeight : 12);

    final buttonLabelHeight = _lineHeight(context, textTheme.labelLarge);
    final buttonContentHeight = ((buttonLabelHeight > 18 ? buttonLabelHeight : 18) + 16).clamp(34, 58).toDouble();
    final detailsHeight = 8 + topContentHeight + 8 + buttonContentHeight + 8;
    final imageHeight = itemWidth / 1.28;

    return imageHeight + detailsHeight + 4;
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
                                _visibleCount = _pageSize;
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
          child: RadioGroup<_DealsSortOption>(
            groupValue: _sortOption,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _sortOption = value;
                _visibleCount = _pageSize;
              });
              Navigator.of(sheetContext).pop();
            },
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
                      title: Text(_sortLabel(option)),
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _dealAddKey(CatalogDealItem deal) => '${deal.productId}_${deal.storeName}_${deal.title}';

  Future<void> _addDealToShoppingList({required CatalogDealItem deal, required String uid}) async {
    final key = _dealAddKey(deal);
    if (_addingDealIds.contains(key)) {
      return;
    }

    setState(() {
      _addingDealIds.add(key);
    });

    try {
      await ref.read(shoppingListRepositoryProvider).addItem(uid: uid, name: deal.title);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${deal.title} added to shopping list')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add item to shopping list')));
    } finally {
      if (mounted) {
        setState(() {
          _addingDealIds.remove(key);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealsAsync = ref.watch(allCatalogDealsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final uid = userAsync.asData?.value?.userId;
    final shoppingListItemsAsync = uid == null
        ? const AsyncValue<List<ShoppingListItem>>.data(<ShoppingListItem>[])
        : ref.watch(shoppingListItemsProvider(uid));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: dealsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load deals: $error')),
          data: (deals) {
            final shoppingListItems = shoppingListItemsAsync.asData?.value ?? const <ShoppingListItem>[];
            final shoppingListKeys = shoppingListItems.map((item) => _normalizedShoppingListKey(item.name)).toSet();
            final filteredDeals = _filterAndSortDeals(deals);
            final visibleCount = _visibleCount < filteredDeals.length ? _visibleCount : filteredDeals.length;
            final visibleDeals = filteredDeals.take(visibleCount).toList(growable: false);
            final hasMore = visibleCount < filteredDeals.length;
            final screenWidth = MediaQuery.sizeOf(context).width;
            final availableWidth = screenWidth - 40;
            final columns = availableWidth < 560 ? 2 : 3;
            final itemWidth = (availableWidth - ((columns - 1) * 12)) / columns;
            final gridMainAxisExtent = _estimateDealsCardMainAxisExtent(context, itemWidth);
            final storeChipRowHeight = (_lineHeight(context, Theme.of(context).textTheme.labelLarge) + 22).clamp(40, 60).toDouble();

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
                          height: storeChipRowHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _storeFilters.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final store = _storeFilters[index];
                              final isSelected = store == 'All' ? _selectedStores.contains('All') : _selectedStores.contains(store);
                              return Center(
                                child: FilterChip(
                                  label: Text(store),
                                  selected: isSelected,
                                  onSelected: (_) => _toggleStore(store),
                                  showCheckmark: false,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
                                  selectedColor: Theme.of(context).colorScheme.primary,
                                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                ),
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
                        const SizedBox(height: 14),
                        Text(
                          'Showing $visibleCount of ${filteredDeals.length} deals',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final deal = visibleDeals[index];
                        final dealKey = _dealAddKey(deal);
                        final alreadyOnShoppingList = shoppingListKeys.contains(_normalizedShoppingListKey(deal.title));
                        return DealsGridCard.fromCatalog(
                          deal: deal,
                          isAddingToShoppingList: _addingDealIds.contains(dealKey),
                          isAlreadyOnShoppingList: alreadyOnShoppingList,
                          onAddToShoppingList: () {
                            if (alreadyOnShoppingList) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This item is already on your shopping list')));
                              return;
                            }
                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to add items to your shopping list')));
                              return;
                            }
                            _addDealToShoppingList(deal: deal, uid: uid);
                          },
                        );
                      }, childCount: visibleDeals.length),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: gridMainAxisExtent,
                      ),
                    ),
                  ),
                if (hasMore)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverToBoxAdapter(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleCount = (_visibleCount + _pageSize) < filteredDeals.length ? (_visibleCount + _pageSize) : filteredDeals.length;
                          });
                        },
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: const Text('Load more')),
                        style: FilledButton.styleFrom(foregroundColor: Colors.white),
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
