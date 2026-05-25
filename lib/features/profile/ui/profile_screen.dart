import 'dart:async';

import 'package:cenko/app_theme.dart';
import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/providers/receipt_revision_provider.dart';
import 'package:cenko/shared/services/receipt_analytics_service.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cenko/shared/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MonthReceiptQuery {
  const _MonthReceiptQuery({required this.uid, required this.month, this.limit = 20});

  final String uid;
  final DateTime month;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is _MonthReceiptQuery &&
        other.uid == uid &&
        other.month.year == month.year &&
        other.month.month == month.month &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(uid, month.year, month.month);
}

class _StoreMonthSpend {
  const _StoreMonthSpend({required this.storeName, required this.spentCents, required this.receiptCount});

  final String storeName;
  final int spentCents;
  final int receiptCount;
}

class _MonthSpendingStats {
  const _MonthSpendingStats({required this.spentCents, required this.receiptsScanned, required this.stores});

  final int spentCents;
  final int receiptsScanned;
  final List<_StoreMonthSpend> stores;
}

class _MonthReceiptItem {
  const _MonthReceiptItem({required this.id, required this.storeName, required this.totalPriceCents, required this.itemCount, required this.date});

  final String id;
  final String storeName;
  final int totalPriceCents;
  final int itemCount;
  final DateTime date;
}

class _MonthReceiptPage {
  const _MonthReceiptPage({required this.receipts, required this.hasMore});

  final List<_MonthReceiptItem> receipts;
  final bool hasMore;
}

final _monthReceiptsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _MonthReceiptQuery>((ref, query) async {
  ref.watch(receiptRevisionProvider); // re-fetch when a receipt is saved or pull-to-refresh
  final year = query.month.year;
  final month = query.month.month;
  final monthStart = '$year-${month.toString().padLeft(2, '0')}-01';
  final nextMonth = DateTime(year, month + 1);
  final nextMonthStart = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';

  final rows = await Supabase.instance.client
      .from('receipt')
      .select('id, total, receipt_date, scanned_at, store:store_id(name), receipt_item(id)')
      .eq('user_id', query.uid)
      .gte('receipt_date', monthStart)
      .lt('receipt_date', nextMonthStart)
      .order('receipt_date', ascending: false)
      .limit(query.limit);
  return (rows as List).map((r) => r as Map<String, dynamic>).toList();
});

_MonthSpendingStats _monthSpendingStatsFromRows(List<Map<String, dynamic>> rows) {
  var spentCents = 0;
  final byStore = <String, _StoreMonthSpend>{};

  for (final r in rows) {
    final storeMap = r['store'] as Map<String, dynamic>?;
    final storeName = (storeMap?['name'] as String?)?.trim().isNotEmpty == true ? (storeMap!['name'] as String).trim() : 'Unknown store';
    final totalPrice = r['total'] is int ? r['total'] as int : 0;

    spentCents += totalPrice;

    final existing = byStore[storeName];
    if (existing == null) {
      byStore[storeName] = _StoreMonthSpend(storeName: storeName, spentCents: totalPrice, receiptCount: 1);
    } else {
      byStore[storeName] = _StoreMonthSpend(
        storeName: existing.storeName,
        spentCents: existing.spentCents + totalPrice,
        receiptCount: existing.receiptCount + 1,
      );
    }
  }

  final stores = byStore.values.toList()..sort((a, b) => b.spentCents.compareTo(a.spentCents));
  return _MonthSpendingStats(spentCents: spentCents, receiptsScanned: rows.length, stores: stores);
}

_MonthReceiptPage _monthReceiptPageFromRows(List<Map<String, dynamic>> rows, int limit) {
  final receipts = rows
      .map((r) {
        final storeMap = r['store'] as Map<String, dynamic>?;
        final storeName = (storeMap?['name'] as String?)?.trim().isNotEmpty == true ? (storeMap!['name'] as String).trim() : 'Unknown store';
        return _MonthReceiptItem(
          id: r['id'].toString(),
          storeName: storeName,
          totalPriceCents: r['total'] is int ? r['total'] as int : 0,
          itemCount: (r['receipt_item'] as List?)?.length ?? 0,
          date: DateTime.tryParse(r['receipt_date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        );
      })
      .toList(growable: false);

  return _MonthReceiptPage(receipts: receipts, hasMore: rows.length > limit);
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _logoutCheckStarted = false;
  static const int _receiptPageSize = 5;
  static const double _monthSwipeDistanceThreshold = 44;
  static const double _monthSwipeVelocityThreshold = 340;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _monthAnimationDirection = 1;
  double _spendingCardDragDx = 0;
  late final List<DateTime> _monthOptions;
  final ReceiptAnalyticsService _receiptAnalyticsService = ReceiptAnalyticsService();
  final Map<String, int> _visibleReceiptsByMonth = <String, int>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    _selectedMonth = currentMonth;
    _visibleReceiptsByMonth[_monthKey(currentMonth)] = _receiptPageSize;
    _monthOptions = [for (var delta = -24; delta <= 0; delta++) DateTime(currentMonth.year, currentMonth.month + delta)];
  }

  void _shiftMonth(int delta) {
    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta));
  }

  void _onSpendingsCardHorizontalDragUpdate(DragUpdateDetails details) {
    _spendingCardDragDx += details.delta.dx;
  }

  void _onSpendingsCardHorizontalDragEnd(DragEndDetails details) {
    final horizontalVelocity = details.primaryVelocity ?? 0;
    final shouldGoPreviousMonth = _spendingCardDragDx > _monthSwipeDistanceThreshold || horizontalVelocity > _monthSwipeVelocityThreshold;
    final shouldGoNextMonth = _spendingCardDragDx < -_monthSwipeDistanceThreshold || horizontalVelocity < -_monthSwipeVelocityThreshold;

    _spendingCardDragDx = 0;

    if (shouldGoPreviousMonth) {
      _shiftMonth(-1);
      return;
    }

    if (shouldGoNextMonth) {
      _shiftMonth(1);
    }
  }

  void _selectMonth(DateTime month) {
    if (!_monthOptions.any((m) => _isSameMonth(m, month))) {
      return;
    }

    if (_isSameMonth(_selectedMonth, month)) {
      return;
    }

    final currentIndex = _selectedMonth.year * 12 + _selectedMonth.month;
    final targetIndex = month.year * 12 + month.month;

    setState(() {
      _monthAnimationDirection = targetIndex >= currentIndex ? 1 : -1;
      _selectedMonth = DateTime(month.year, month.month);
      _visibleReceiptsByMonth.putIfAbsent(_monthKey(_selectedMonth), () => _receiptPageSize);
    });
  }

  int _visibleReceiptCountForMonth(DateTime month) {
    return _visibleReceiptsByMonth.putIfAbsent(_monthKey(month), () => _receiptPageSize);
  }

  void _loadMoreReceiptsForMonth(DateTime month) {
    setState(() {
      final key = _monthKey(month);
      _visibleReceiptsByMonth[key] = (_visibleReceiptsByMonth[key] ?? _receiptPageSize) + _receiptPageSize;
    });
  }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  String _monthKey(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime month) {
    final locale = Localizations.localeOf(context).languageCode;
    final label = DateFormat('MMMM yyyy', locale).format(month);
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    final l10n = AppLocalizations.of(context)!;

    return userAsync.when(
      loading: () => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              children: [
                MainTopBar(title: l10n.navProfile),
                const Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              children: [
                MainTopBar(title: l10n.navProfile),
                Expanded(child: Center(child: Text(error.toString()))),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          // The user document may take a short time to appear after registration.
          // Start a one-time delayed check: show a loading spinner for a few
          // seconds and then sign out if the user document is still missing.
          if (!_logoutCheckStarted) {
            _logoutCheckStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(seconds: 3), () {
                if (!mounted) return;
                final current = ref.read(currentUserProvider).asData?.value;
                if (current == null) {
                  ref.read(authNotifierProvider).signOut();
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    context.go('/login');
                  }
                }
              });
            });
          }

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  children: [
                    MainTopBar(title: l10n.navProfile),
                    const Expanded(child: Center(child: CircularProgressIndicator())),
                  ],
                ),
              ),
            ),
          );
        }

        final monthReceiptsSnapshotAsync = ref.watch(_monthReceiptsProvider(_MonthReceiptQuery(uid: user.id, month: _selectedMonth, limit: 100)));
        final visibleReceiptCount = _visibleReceiptCountForMonth(_selectedMonth);

        final colorScheme = Theme.of(context).colorScheme;
        final initials = user.displayName.trim().isEmpty
            ? 'U'
            : user.displayName.trim().split(RegExp(r'\s+')).take(2).map((part) => part.isNotEmpty ? part[0] : '').join().toUpperCase();
        final selectedMonthIndex = _monthOptions.indexWhere((m) => _isSameMonth(m, _selectedMonth));

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(receiptRevisionProvider.notifier).increment();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MainTopBar(title: l10n.navProfile),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withValues(alpha: 0.28)),
                              child: Text(initials, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.displayName, style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.profileMemberSince(displayDate(user.joinedAt)),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: selectedMonthIndex > 0 ? () => _shiftMonth(-1) : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: l10n.profilePreviousMonth,
                          ),
                          Expanded(
                            child: Center(child: Text(_monthLabel(_selectedMonth), style: Theme.of(context).textTheme.titleMedium)),
                          ),
                          IconButton(
                            onPressed: selectedMonthIndex < _monthOptions.length - 1 ? () => _shiftMonth(1) : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: l10n.profileNextMonth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _onSpendingsCardHorizontalDragUpdate,
                      onHorizontalDragEnd: _onSpendingsCardHorizontalDragEnd,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.profileSpendings,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: Offset(0.2 * _monthAnimationDirection, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return FadeTransition(
                                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                                  child: SlideTransition(position: slide, child: child),
                                );
                              },
                              child: Column(
                                key: ValueKey(_monthKey(_selectedMonth)),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  monthReceiptsSnapshotAsync.when(
                                    loading: () => const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 18),
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    error: (error, _) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        'Failed to load spendings: ${error.toString().replaceFirst('Exception: ', '')}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                    data: (rows) {
                                      final monthStats = _monthSpendingStatsFromRows(rows);
                                      final monthReceiptsPage = _monthReceiptPageFromRows(rows, visibleReceiptCount);
                                      final stores = monthStats.stores;
                                      final maxSpend = stores.fold<int>(0, (max, s) => s.spentCents > max ? s.spentCents : max);
                                      final hasReceiptScans = monthStats.receiptsScanned > 0;
                                      final shouldShowFirstScanButton = !hasReceiptScans;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(_monthLabel(_selectedMonth), style: Theme.of(context).textTheme.titleLarge),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      l10n.profileReceiptsScanned(monthStats.receiptsScanned),
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                formatCents(monthStats.spentCents),
                                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ],
                                          ),
                                          if (shouldShowFirstScanButton) ...[
                                            const SizedBox(height: 16),
                                            Text(
                                              l10n.profileScanFirstReceiptPrompt,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: () => context.go('/scan?mode=receipt'),
                                                style: FilledButton.styleFrom(foregroundColor: Colors.white),
                                                icon: const Icon(Icons.receipt_long_rounded),
                                                label: Text(l10n.profileScanFirstReceiptBtn),
                                              ),
                                            ),
                                          ],
                                          if (!hasReceiptScans && !shouldShowFirstScanButton) ...[
                                            const SizedBox(height: 16),
                                            Text(l10n.profileNoReceiptsThisMonth, style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                          if (hasReceiptScans) ...[
                                            const SizedBox(height: 12),
                                            Divider(color: colorScheme.surfaceContainerHighest),
                                            const SizedBox(height: 10),
                                            Text(l10n.profileSpendingsByStore, style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 8),
                                            if (stores.isEmpty)
                                              Text(l10n.profileNoReceiptsThisMonth, style: Theme.of(context).textTheme.bodyMedium)
                                            else
                                              Column(
                                                children: [
                                                  for (final store in stores.take(4))
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 8),
                                                      child: _StoreSpendRow(
                                                        storeName: store.storeName,
                                                        progress: maxSpend == 0 ? 0 : store.spentCents / maxSpend,
                                                        amountLabel: formatCents(store.spentCents),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            const SizedBox(height: 16),
                                            Divider(color: colorScheme.surfaceContainerHighest),
                                            const SizedBox(height: 10),
                                            Text(l10n.profileRecentReceipts, style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 8),
                                            if (monthReceiptsPage.receipts.isEmpty)
                                              Text(l10n.profileNoReceiptsThisMonth, style: Theme.of(context).textTheme.bodyMedium)
                                            else
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ListView.separated(
                                                    itemCount: monthReceiptsPage.receipts.length,
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    separatorBuilder: (_, _) => const SizedBox(height: 1),
                                                    itemBuilder: (context, index) {
                                                      final receipt = monthReceiptsPage.receipts[index];
                                                      Offset? pressPosition;
                                                      return Dismissible(
                                                        key: ValueKey(receipt.id),
                                                        direction: DismissDirection.endToStart,
                                                        movementDuration: const Duration(milliseconds: 180),
                                                        resizeDuration: const Duration(milliseconds: 180),
                                                        confirmDismiss: (_) =>
                                                            _confirmDeleteReceipt(context: context, uid: user.id, receipt: receipt),
                                                        background: Container(
                                                          alignment: Alignment.centerRight,
                                                          padding: const EdgeInsets.only(right: 18),
                                                          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                                                          child: const Icon(Icons.delete_rounded, color: AppColors.onError),
                                                        ),
                                                        child: Listener(
                                                          behavior: HitTestBehavior.translucent,
                                                          onPointerDown: (event) => pressPosition = event.position,
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(16),
                                                            child: _MonthReceiptTile(
                                                              storeName: receipt.storeName,
                                                              dateLabel: displayDate(receipt.date),
                                                              totalLabel: formatCents(receipt.totalPriceCents),
                                                              itemLabel: l10n.profileReceiptItemCount(receipt.itemCount),
                                                              onTap: () => context.push('/receipt/${receipt.id}'),
                                                              onLongPress: () =>
                                                                  _showReceiptContextMenu(context, user.id, receipt, pressPosition ?? Offset.zero),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  if (monthReceiptsPage.hasMore) ...[
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: OutlinedButton(
                                                        onPressed: () => _loadMoreReceiptsForMonth(_selectedMonth),
                                                        child: Text(l10n.loadMore),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // TODO - premium plan details and benefits page
                    // const SizedBox(height: 30),
                    // Container(
                    //   width: double.infinity,
                    //   decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Padding(
                    //         padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    //         child: Text(
                    //           'PLAN',
                    //           style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: colorScheme.onSurfaceVariant),
                    //         ),
                    //       ),
                    //       _SettingsRow(label: 'Upgrade to Premium', onTap: () => context.push('/premium')),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsRow(label: l10n.settingsTitle, onTap: () => context.push('/settings')),
                          _SettingsRow(label: l10n.profileAbout, onTap: () => context.push('/about')),
                          _SettingsRow(label: l10n.profileLegal, onTap: () => context.push('/legal')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => ref.read(authNotifierProvider).signOut(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                        child: Text(l10n.profileLogOut, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.error)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteReceipt({required BuildContext context, required String uid, required _MonthReceiptItem receipt}) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var deleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.profileDeleteReceiptTitle, style: Theme.of(context).textTheme.titleLarge)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.profileDeleteReceiptBody, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: deleting ? null : () => Navigator.of(dialogContext).pop(false),
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                              onPressed: deleting
                                  ? null
                                  : () async {
                                      setDialogState(() => deleting = true);
                                      try {
                                        await _receiptAnalyticsService.deleteReceiptAndResyncCommonProducts(uid: uid, receiptId: receipt.id);
                                        ref.read(receiptRevisionProvider.notifier).increment();
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop(true);
                                        }
                                        if (!context.mounted) {
                                          return;
                                        }
                                        if (mounted) {
                                          SnackBarService.show(l10n.profileReceiptDeleted);
                                        }
                                      } catch (error) {
                                        if (!dialogContext.mounted) {
                                          return;
                                        }
                                        setDialogState(() => deleting = false);
                                        SnackBarService.show(l10n.errorFailedToDeleteReceipt);
                                      }
                                    },
                              child: deleting
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(l10n.delete),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return shouldDelete == true;
  }

  void _showReceiptContextMenu(BuildContext context, String uid, _MonthReceiptItem receipt, Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final Size overlaySize = overlay?.size ?? MediaQuery.of(context).size;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlaySize.width - globalPosition.dx,
      overlaySize.height - globalPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.remove, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'remove') {
        // TODO
        // ignore: use_build_context_synchronously
        _confirmDeleteReceipt(context: context, uid: uid, receipt: receipt);
      }
    });
  }
}

class _StoreSpendRow extends StatelessWidget {
  const _StoreSpendRow({required this.storeName, required this.progress, required this.amountLabel});

  final String storeName;
  final double progress;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final storeWidth = (maxWidth * 0.3).clamp(88.0, 142.0);
        final amountWidth = (maxWidth * 0.24).clamp(74.0, 112.0);

        return Row(
          children: [
            SizedBox(
              width: storeWidth,
              child: Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress.clamp(0, 1),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: amountWidth,
              child: Text(
                amountLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthReceiptTile extends StatelessWidget {
  const _MonthReceiptTile({
    required this.storeName,
    required this.dateLabel,
    required this.totalLabel,
    required this.itemLabel,
    this.onTap,
    this.onLongPress,
  });

  final String storeName;
  final String dateLabel;
  final String totalLabel;
  final String itemLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trailingPriceWidth = (constraints.maxWidth * 0.26).clamp(78.0, 116.0);

              return Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '$dateLabel · $itemLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: trailingPriceWidth,
                      child: Text(
                        totalLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
