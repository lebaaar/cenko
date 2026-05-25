import 'package:cenko/app_theme.dart';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/features/home/data/home_deal_card_item.dart';
import 'package:cenko/features/home/data/personalized_deals_provider.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/widgets/deal_card.dart';
import 'package:cenko/shared/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 18) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final uid = ref.read(currentUserProvider).asData?.value?.id;
            if (uid != null) {
              ref.invalidate(shoppingListOnSaleProvider(uid));
              ref.invalidate(commonBoughtProductsOnSaleProvider(uid));
              await Future.wait([ref.read(shoppingListOnSaleProvider(uid).future), ref.read(commonBoughtProductsOnSaleProvider(uid).future)]);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: userAsync.when(
              loading: () => SizedBox(
                height: MediaQuery.of(context).size.height - 100,
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Center(child: Text(AppLocalizations.of(context)!.errorGeneric)),
              data: (user) {
                final name = user?.displayName.trim().isNotEmpty == true ? user!.displayName.trim() : 'there';
                final secondaryBodyStyle = Theme.of(context).textTheme.bodyMedium;
                final shoppingListDealsAsync = user == null
                    ? const AsyncValue<List<PersonalizedDealCardItem>>.data([])
                    : ref.watch(shoppingListOnSaleProvider(user.id));
                final commonBoughtProductsDealsAsync = user == null
                    ? const AsyncValue<List<PersonalizedDealCardItem>>.data([])
                    : ref.watch(commonBoughtProductsOnSaleProvider(user.id));
                final shoppingListSaleCount = shoppingListDealsAsync.asData?.value.length ?? 0;
                final commonBoughtProductsSaleCount = commonBoughtProductsDealsAsync.asData?.value.length ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MainTopBar(title: kAppName),
                    Text('${_greeting(l10n)}, $name', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 12),
                    if (shoppingListSaleCount + commonBoughtProductsSaleCount > 0)
                      Text.rich(
                        TextSpan(
                          style: secondaryBodyStyle,
                          children: [
                            TextSpan(
                              text: '${shoppingListSaleCount + commonBoughtProductsSaleCount}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, height: 1.4),
                            ),
                            TextSpan(
                              text: l10n.homeItemsOnSaleSuffix(shoppingListSaleCount + commonBoughtProductsSaleCount),
                              style: secondaryBodyStyle,
                            ),
                          ],
                        ),
                      )
                    else
                      Text(l10n.homeEmptyState, style: secondaryBodyStyle),
                    const SizedBox(height: 18),
                    _SectionHeader(title: l10n.homeFromShoppingLists),
                    const SizedBox(height: 14),
                    _DealsList(
                      asyncDeals: shoppingListDealsAsync,
                      emptyMessage: l10n.homeEmptyShoppingListDeals,
                      message: l10n.homeShoppingListDealsMessage,
                      emptyActionLabel: l10n.homeGoToShoppingLists,
                      emptyActionIcon: Icons.checklist_rounded,
                      emptyActionRoute: '/list',
                      onDealTap: (item) => context.push('/deal/${item.dealId}'),
                    ),
                    const SizedBox(height: 30),
                    _SectionHeader(title: l10n.homeBasedOnHabits),
                    const SizedBox(height: 14),
                    _DealsList(
                      asyncDeals: commonBoughtProductsDealsAsync,
                      emptyMessage: l10n.homeEmptyHabitsDeals,
                      message: l10n.homeHabitsDealsMessage,
                      emptyActionLabel: l10n.homeScanAReceipt,
                      emptyActionIcon: Icons.document_scanner_rounded,
                      emptyActionRoute: '/scan',
                      onDealTap: (item) => context.push('/deal/${item.dealId}'),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.go('/deals'),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          l10n.homeShowAllDeals,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
  }
}

class _DealsList extends StatefulWidget {
  const _DealsList({
    required this.asyncDeals,
    required this.emptyMessage,
    required this.message,
    this.emptyActionLabel,
    this.emptyActionIcon,
    this.emptyActionRoute,
    this.onDealTap,
  });

  final AsyncValue<List<PersonalizedDealCardItem>> asyncDeals;
  final String emptyMessage;
  final String message;
  final String? emptyActionLabel;
  final IconData? emptyActionIcon;
  final String? emptyActionRoute;
  final ValueChanged<PersonalizedDealCardItem>? onDealTap;

  @override
  State<_DealsList> createState() => _DealsListState();
}

class _DealsListState extends State<_DealsList> {
  static const int _pageSize = 10;
  int _visibleCount = _pageSize;

  @override
  void didUpdateWidget(covariant _DealsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCount = oldWidget.asyncDeals.asData?.value.length;
    final newCount = widget.asyncDeals.asData?.value.length;
    if (oldCount != newCount) {
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.asyncDeals.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(AppLocalizations.of(context)!.errorFailedToLoadDeals, style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.emptyActionLabel != null && widget.emptyActionRoute != null) ...[
                Text(widget.emptyMessage, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => context.go(widget.emptyActionRoute!),
                  icon: Icon(widget.emptyActionIcon),
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  label: Text(widget.emptyActionLabel!),
                ),
              ] else ...[
                Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          );
        }

        final visibleCount = _visibleCount > items.length ? items.length : _visibleCount;
        final visibleItems = items.take(visibleCount);
        final hasMore = visibleCount < items.length;

        return Column(
          children: [
            for (final item in visibleItems) ...[
              DealCard(item: item, onTap: widget.onDealTap != null ? () => widget.onDealTap!(item) : null),
              const SizedBox(height: 10),
            ],
            if (hasMore)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _visibleCount = (_visibleCount + _pageSize) > items.length ? items.length : (_visibleCount + _pageSize);
                    });
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(l10n.loadMore),
                ),
              ),
          ],
        );
      },
    );
  }
}
