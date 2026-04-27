import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/receipt_analytics_service.dart';
import 'package:cenko/shared/widgets/top_bar.dart';
import 'package:go_router/go_router.dart';

class _MonthReceiptQuery {
  const _MonthReceiptQuery({required this.uid, required this.month, required this.limit});

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
  int get hashCode => Object.hash(uid, month.year, month.month, limit);
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

final _monthSpendingStatsProvider = StreamProvider.family<_MonthSpendingStats, _MonthReceiptQuery>((ref, query) {
  final monthStartLocal = DateTime(query.month.year, query.month.month);
  final nextMonthStartLocal = DateTime(query.month.year, query.month.month + 1);

  final monthStart = Timestamp.fromDate(monthStartLocal.toUtc());
  final nextMonthStart = Timestamp.fromDate(nextMonthStartLocal.toUtc());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(query.uid)
      .collection('receipts')
      .where('date', isGreaterThanOrEqualTo: monthStart)
      .where('date', isLessThan: nextMonthStart)
      .snapshots()
      .map((snapshot) {
        var spentCents = 0;
        final byStore = <String, _StoreMonthSpend>{};

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final storeName = (data['store_name'] as String?)?.trim().isNotEmpty == true ? (data['store_name'] as String).trim() : 'Unknown store';
          final totalPrice = data['total_price'] is int ? data['total_price'] as int : 0;

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

        return _MonthSpendingStats(spentCents: spentCents, receiptsScanned: snapshot.size, stores: stores);
      });
});

final _monthReceiptsProvider = StreamProvider.family<_MonthReceiptPage, _MonthReceiptQuery>((ref, query) {
  final monthStartLocal = DateTime(query.month.year, query.month.month);
  final nextMonthStartLocal = DateTime(query.month.year, query.month.month + 1);

  final monthStart = Timestamp.fromDate(monthStartLocal.toUtc());
  final nextMonthStart = Timestamp.fromDate(nextMonthStartLocal.toUtc());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(query.uid)
      .collection('receipts')
      .where('date', isGreaterThanOrEqualTo: monthStart)
      .where('date', isLessThan: nextMonthStart)
      .orderBy('date', descending: true)
      .limit(query.limit)
      .snapshots()
      .map((snapshot) {
        final receipts = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return _MonthReceiptItem(
                id: doc.id,
                storeName: _monthReceiptStoreName(data),
                totalPriceCents: data['total_price'] is int ? data['total_price'] as int : 0,
                itemCount: data['item_count'] is int ? data['item_count'] as int : 0,
                date: _monthReceiptDate(data['date']),
              );
            })
            .toList(growable: false);

        return _MonthReceiptPage(receipts: receipts, hasMore: snapshot.docs.length == query.limit);
      });
});

final _hasAnyReceiptsProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('receipts')
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty);
});

String _monthReceiptStoreName(Map<String, dynamic> data) {
  final storeName = (data['store_name'] as String?)?.trim();
  return storeName == null || storeName.isEmpty ? 'Unknown store' : storeName;
}

DateTime _monthReceiptDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toLocal();
  }

  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal() ?? DateTime.now();
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${monthNames[month.month - 1]} ${month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              children: const [
                MainTopBar(title: 'Profile'),
                Expanded(child: Center(child: CircularProgressIndicator())),
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
                const MainTopBar(title: 'Profile'),
                Expanded(child: Center(child: Text(error.toString()))),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authNotifierProvider).signOut();
            context.go('/auth');
          });
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  children: const [
                    MainTopBar(title: 'Profile'),
                    Expanded(child: Center(child: Text('Signing out...'))),
                  ],
                ),
              ),
            ),
          );
        }

        final monthStatsAsync = ref.watch(
          _monthSpendingStatsProvider(_MonthReceiptQuery(uid: user.userId, month: _selectedMonth, limit: _receiptPageSize)),
        );
        final hasAnyReceiptsAsync = ref.watch(_hasAnyReceiptsProvider(user.userId));
        final visibleReceiptCount = _visibleReceiptCountForMonth(_selectedMonth);

        final colorScheme = Theme.of(context).colorScheme;
        final initials = user.name.trim().isEmpty
            ? 'U'
            : user.name.trim().split(RegExp(r'\s+')).take(2).map((part) => part.isNotEmpty ? part[0] : '').join().toUpperCase();
        final selectedMonthIndex = _monthOptions.indexWhere((m) => _isSameMonth(m, _selectedMonth));

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MainTopBar(title: 'Profile'),
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
                                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 2),
                                Text(
                                  'Member since ${displayDate(user.createdAt)}',
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
                          tooltip: 'Previous month',
                        ),
                        Expanded(
                          child: Center(child: Text(_monthLabel(_selectedMonth), style: Theme.of(context).textTheme.titleMedium)),
                        ),
                        IconButton(
                          onPressed: selectedMonthIndex < _monthOptions.length - 1 ? () => _shiftMonth(1) : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: 'Next month',
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
                            'SPENDINGS',
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
                                monthStatsAsync.when(
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
                                  data: (monthStats) {
                                    final stores = monthStats.stores;
                                    final maxSpend = stores.fold<int>(0, (max, s) => s.spentCents > max ? s.spentCents : max);
                                    final hasReceiptScans = monthStats.receiptsScanned > 0;
                                    final shouldShowFirstScanButton = !hasReceiptScans && hasAnyReceiptsAsync.asData?.value == false;
                                    final monthReceiptsAsync = hasReceiptScans
                                        ? ref.watch(
                                            _monthReceiptsProvider(
                                              _MonthReceiptQuery(uid: user.userId, month: _selectedMonth, limit: visibleReceiptCount),
                                            ),
                                          )
                                        : null;

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
                                                    'Receipts scanned: ${monthStats.receiptsScanned}',
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
                                            'Scan your first receipt to start tracking spendings',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.icon(
                                              onPressed: () => context.go('/scan?mode=receipt'),
                                              style: FilledButton.styleFrom(foregroundColor: Colors.white),
                                              icon: const Icon(Icons.receipt_long_rounded),
                                              label: const Text('Scan first receipt'),
                                            ),
                                          ),
                                        ],
                                        if (!hasReceiptScans && !shouldShowFirstScanButton) ...[
                                          const SizedBox(height: 16),
                                          Text('No receipts scanned in this month', style: Theme.of(context).textTheme.bodyMedium),
                                        ],
                                        if (hasReceiptScans) ...[
                                          const SizedBox(height: 12),
                                          Divider(color: colorScheme.surfaceContainerHighest),
                                          const SizedBox(height: 10),
                                          Text('Spendings by store', style: Theme.of(context).textTheme.titleMedium),
                                          const SizedBox(height: 8),
                                          if (stores.isEmpty)
                                            Text('No receipts scanned in this month', style: Theme.of(context).textTheme.bodyMedium)
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
                                          Text('Recent receipts', style: Theme.of(context).textTheme.titleMedium),
                                          const SizedBox(height: 8),
                                          if (monthReceiptsAsync != null)
                                            monthReceiptsAsync.when(
                                              loading: () => const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 10),
                                                child: Center(child: CircularProgressIndicator()),
                                              ),
                                              error: (error, _) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Text(
                                                  'Failed to load receipts: ${error.toString().replaceFirst('Exception: ', '')}',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                              ),
                                              data: (page) {
                                                if (page.receipts.isEmpty) {
                                                  return Text('No receipts scanned in this month', style: Theme.of(context).textTheme.bodyMedium);
                                                }

                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    ListView.separated(
                                                      itemCount: page.receipts.length,
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      separatorBuilder: (_, _) => const SizedBox(height: 1),
                                                      itemBuilder: (context, index) {
                                                        final receipt = page.receipts[index];
                                                        return Dismissible(
                                                          key: ValueKey(receipt.id),
                                                          direction: DismissDirection.endToStart,
                                                          movementDuration: const Duration(milliseconds: 180),
                                                          resizeDuration: const Duration(milliseconds: 180),
                                                          confirmDismiss: (_) =>
                                                              _confirmDeleteReceipt(context: context, uid: user.userId, receipt: receipt),
                                                          background: Container(
                                                            alignment: Alignment.centerRight,
                                                            padding: const EdgeInsets.only(right: 18),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.errorContainer,
                                                              borderRadius: BorderRadius.circular(16),
                                                            ),
                                                            child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                                                          ),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(16),
                                                            child: _MonthReceiptTile(
                                                              storeName: receipt.storeName,
                                                              dateLabel: displayDate(receipt.date),
                                                              totalLabel: formatCents(receipt.totalPriceCents),
                                                              itemLabel: '${receipt.itemCount} item${receipt.itemCount == 1 ? '' : 's'}',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    if (page.hasMore) ...[
                                                      const SizedBox(height: 12),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: OutlinedButton(
                                                          onPressed: () => _loadMoreReceiptsForMonth(_selectedMonth),
                                                          child: const Text('Load more'),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              },
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            'SETTINGS',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        _SettingsRow(label: 'Account', onTap: () => context.push('/settings')),
                        _SettingsRow(label: 'Legal', onTap: () => context.push('/legal')),
                        _SettingsRow(label: 'About', onTap: () => context.push('/about')),
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
                      child: Text('Log out', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.error)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteReceipt({required BuildContext context, required String uid, required _MonthReceiptItem receipt}) async {
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
                          Expanded(child: Text('Delete receipt?', style: Theme.of(context).textTheme.titleLarge)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('This receipt will be removed from your spending history', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: deleting ? null : () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
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
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop(true);
                                        }
                                        if (!context.mounted) {
                                          return;
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt deleted')));
                                        }
                                      } catch (error) {
                                        if (!dialogContext.mounted) {
                                          return;
                                        }
                                        setDialogState(() => deleting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to delete receipt: ${error.toString().replaceFirst('Exception: ', '')}')),
                                        );
                                      }
                                    },
                              child: Text(deleting ? 'Deleting...' : 'Delete'),
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
  const _MonthReceiptTile({required this.storeName, required this.dateLabel, required this.totalLabel, required this.itemLabel});

  final String storeName;
  final String dateLabel;
  final String totalLabel;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
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
              SizedBox(
                width: trailingPriceWidth,
                child: Text(
                  totalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
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
