import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/widgets/top_bar.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _monthAnimationDirection = 1;
  late final List<DateTime> _monthOptions;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    _selectedMonth = currentMonth;
    _monthOptions = [for (var delta = -24; delta <= 0; delta++) DateTime(currentMonth.year, currentMonth.month + delta)];
  }

  void _shiftMonth(int delta) {
    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta));
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
        final colorScheme = Theme.of(context).colorScheme;
        final initials = user == null || user.name.trim().isEmpty
            ? 'U'
            : user.name.trim().split(RegExp(r'\s+')).take(2).map((part) => part.isNotEmpty ? part[0] : '').join().toUpperCase();
        final stores = user?.stats.mostVisitedStores ?? const [];
        final selectedMonthIsCurrent = _selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month;
        final selectedMonthIndex = _monthOptions.indexWhere((m) => _isSameMonth(m, _selectedMonth));
        final spentCents = selectedMonthIsCurrent ? (user?.stats.totalSpent ?? 0) : ((user?.stats.totalSpent ?? 0) * 0.82).round();
        final totalVisits = stores.fold<int>(0, (sum, s) => sum + s.visitCount);
        final maxVisits = stores.fold<int>(0, (max, s) => s.visitCount > max ? s.visitCount : max);

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MainTopBar(title: 'Profile'),
                  Container(
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
                              Text(user?.name ?? 'Profile', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                'Member since ${displayDate(user?.createdAt)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('This month', style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 2),
                                        Text(
                                          selectedMonthIsCurrent ? 'Receipts scanned: ${user?.stats.receiptsScanned ?? 0}' : 'Past month estimate',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatCents(spentCents),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: colorScheme.surfaceContainerHighest),
                              const SizedBox(height: 10),
                              Text('${_monthLabel(_selectedMonth).split(' ').first} by store', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              if (stores.isEmpty)
                                Text('No store data yet. Scan receipts to see your spending habits.', style: Theme.of(context).textTheme.bodyMedium)
                              else
                                Column(
                                  children: [
                                    for (final store in stores.take(4))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _StoreSpendRow(
                                          storeName: store.storeName,
                                          progress: maxVisits == 0 ? 0 : store.visitCount / maxVisits,
                                          amountLabel: formatCents(totalVisits == 0 ? 0 : (spentCents * store.visitCount ~/ totalVisits)),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
}

class _StoreSpendRow extends StatelessWidget {
  const _StoreSpendRow({required this.storeName, required this.progress, required this.amountLabel});

  final String storeName;
  final double progress;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 76, child: Text(storeName, style: Theme.of(context).textTheme.bodyMedium)),
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
          width: 56,
          child: Text(amountLabel, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
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
