import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/core/utils/store_util.dart';
import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _dealByIdProvider = FutureProvider.autoDispose.family<CatalogDealItem?, String>((ref, dealId) async {
  final doc = await FirebaseFirestore.instance.collection('products').doc(dealId).get();
  if (!doc.exists) return null;
  return CatalogDealItem.fromFirestore(doc);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _addingToList = false;

  Future<void> _addToShoppingList(CatalogDealItem deal) async {
    if (_addingToList) return;

    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null) {
      SnackBarService.show('Sign in to add items to your shopping list');
      return;
    }

    final uid = user.userId;
    final lists = ref.read(userShoppingListsProvider(uid)).asData?.value ?? [];
    if (lists.isEmpty) {
      SnackBarService.show('No shopping lists found. Create one first.');
      return;
    }

    String? listId;
    if (lists.length == 1) {
      listId = lists.first.id;
    } else {
      listId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (_, controller) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text('Add to list', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        ...lists.map(
                          (list) => ListTile(
                            leading: const Icon(Icons.checklist_rounded),
                            title: Text(list.name),
                            subtitle: Text('${list.itemCount} items'),
                            onTap: () => Navigator.of(sheetContext).pop(list.id),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (listId == null || !mounted) return;

    setState(() => _addingToList = true);
    try {
      await ref.read(sharedShoppingListRepositoryProvider).addItem(listId: listId, addedBy: uid, name: deal.title);
      if (mounted) {
        SnackBarService.show('Added to shopping list');
        context.pop();
      }
    } catch (_) {
      if (mounted) SnackBarService.show('Failed to add item to shopping list');
    } finally {
      if (mounted) setState(() => _addingToList = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealAsync = ref.watch(_dealByIdProvider(widget.dealId));

    return dealAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: Text(e.toString())),
      ),
      data: (deal) {
        if (deal == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
            body: const Center(child: Text('Deal not found')),
          );
        }
        return _ProductDetailView(deal: deal, onAddToList: () => _addToShoppingList(deal), isAddingToList: _addingToList);
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.deal, required this.onAddToList, required this.isAddingToList});

  final CatalogDealItem deal;
  final VoidCallback onAddToList;
  final bool isAddingToList;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = deal.imageUrl != null && deal.imageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasImage ? 280.0 : 0,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => context.pop(),
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.arrow_back_rounded)),
                ),
              ),
            ),
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: _HeroImage(imageUrl: deal.imageUrl!, storeName: deal.storeName),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(deal.productName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
                if (deal.brand != null) ...[
                  const SizedBox(height: 4),
                  Text(deal.brand!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 16),
                _StorePriceCard(deal: deal),
                const SizedBox(height: 12),
                _ValidityCard(deal: deal),
                if (deal.category != null) ...[
                  const SizedBox(height: 12),
                  _InfoTile(icon: Icons.category_rounded, label: 'Category', value: deal.category!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isAddingToList ? null : onAddToList,
                    icon: isAddingToList
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.playlist_add_rounded),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Add to shopping list')),
                    style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePriceCard extends StatelessWidget {
  const _StorePriceCard({required this.deal});

  final CatalogDealItem deal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final discount = deal.discountPercent ?? 0;
    final logo = storeLogoAsset(deal.storeName);

    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                if (logo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(logo, width: 32, height: 32, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(Icons.storefront_rounded, size: 24, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                ],
                Text(storeDisplayName(deal.storeName), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          // Price section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatCents(deal.salePriceCents),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.primary),
                    ),
                    if (discount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          '-$discount%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Was ${formatCents(deal.originalPrice)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidityCard extends StatelessWidget {
  const _ValidityCard({required this.deal});

  final CatalogDealItem deal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deal.validFrom != null || deal.validUntil != null) ...[
            if (deal.validFrom != null) _ValidityRow(label: 'Valid from', date: deal.validFrom!),
            if (deal.validFrom != null && deal.validUntil != null) const SizedBox(height: 10),
            if (deal.validUntil != null) _ValidityRow(label: 'Valid until', date: deal.validUntil!),
          ],
        ],
      ),
    );
  }
}

class _ValidityRow extends StatelessWidget {
  const _ValidityRow({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('$label:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(width: 6),
        Text(displayDate(date), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text('$label:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatefulWidget {
  const _HeroImage({required this.imageUrl, required this.storeName});

  final String imageUrl;
  final String storeName;

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  bool _loadFailed = false;

  void _openFullscreen() {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _FullscreenImageViewer(imageUrl: widget.imageUrl),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loadFailed ? null : _openFullscreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loadFailed = true);
              });
              return _StoreFallbackImage(storeName: widget.storeName);
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1.0],
                colors: [Colors.transparent, Color(0x33000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreFallbackImage extends StatelessWidget {
  const _StoreFallbackImage({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logo = storeLogoAsset(storeName);
    return Container(
      color: colorScheme.surfaceContainer,
      child: Center(
        child: logo != null
            ? Image.asset(logo, width: 110, height: 110, fit: BoxFit.contain)
            : Icon(Icons.local_offer_outlined, color: colorScheme.primary, size: 56),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black87),
          ),
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
