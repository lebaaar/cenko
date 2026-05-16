import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _receiptDocProvider =
    StreamProvider.autoDispose.family<DocumentSnapshot<Map<String, dynamic>>, ({String uid, String receiptId})>((ref, args) {
  return FirebaseFirestore.instance.collection('users').doc(args.uid).collection('receipts').doc(args.receiptId).snapshots();
});

final _receiptItemsProvider =
    StreamProvider.autoDispose.family<QuerySnapshot<Map<String, dynamic>>, ({String uid, String receiptId})>((ref, args) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(args.uid)
      .collection('receipts')
      .doc(args.receiptId)
      .collection('items')
      .orderBy('total_price', descending: true)
      .snapshots();
});

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final args = (uid: uid, receiptId: receiptId);
    final receiptAsync = ref.watch(_receiptDocProvider(args));
    final itemsAsync = ref.watch(_receiptItemsProvider(args));

    return receiptAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: Text(e.toString())),
      ),
      data: (receiptDoc) {
        if (!receiptDoc.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Receipt'), leading: BackButton(onPressed: () => context.pop())),
            body: const Center(child: Text('Receipt not found')),
          );
        }

        final data = receiptDoc.data()!;
        final storeName = _parseStoreName(data);
        final date = _parseDate(data['date']);
        final totalPriceCents = data['total_price'] is int ? data['total_price'] as int : 0;

        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(storeName),
            leading: BackButton(onPressed: () => context.pop()),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReceiptHeaderCard(storeName: storeName, date: date, totalPriceCents: totalPriceCents),
                const SizedBox(height: 12),
                _ItemsCard(itemsAsync: itemsAsync),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _parseStoreName(Map<String, dynamic> data) {
  final s = (data['store_name'] as String?)?.trim();
  return s == null || s.isEmpty ? 'Unknown store' : s;
}

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal() ?? DateTime.now();
}

String? _storeLogoAsset(String storeName) {
  final s = storeName.toLowerCase();
  if (s.contains('tus drogerija') || s.contains('tuš drogerija')) return 'assets/images/tus-drogerija.jpg';
  if (s.contains('lidl')) return 'assets/images/lidl.png';
  if (s.contains('hofer')) return 'assets/images/hofer.png';
  if (s.contains('spar')) return 'assets/images/spar.png';
  if (s.contains('mercator')) return 'assets/images/mercator.webp';
  if (s.contains('tus') || s.contains('tuš')) return 'assets/images/tus.png';
  if (s.contains('eurospin')) return 'assets/images/eurospin.png';
  return null;
}

String _timeLabel(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _ReceiptHeaderCard extends StatelessWidget {
  const _ReceiptHeaderCard({required this.storeName, required this.date, required this.totalPriceCents});

  final String storeName;
  final DateTime date;
  final int totalPriceCents;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoAsset = _storeLogoAsset(storeName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: logoAsset != null
                ? Image.asset(logoAsset, width: 56, height: 56, fit: BoxFit.contain)
                : Icon(Icons.receipt_long_rounded, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(storeName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  '${displayWordedDate(date)} · ${_timeLabel(date)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCents(totalPriceCents),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.itemsAsync});

  final AsyncValue<QuerySnapshot<Map<String, dynamic>>> itemsAsync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: itemsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          'Failed to load items: ${e.toString().replaceFirst('Exception: ', '')}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        data: (snapshot) {
          final items = snapshot.docs;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ITEMS (${items.length})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: colorScheme.onSurfaceVariant),
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 12),
                Text('No items', style: Theme.of(context).textTheme.bodyMedium),
              ] else ...[
                const SizedBox(height: 4),
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.15), height: 1),
                  _ItemRow(data: items[i].data()),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : ((data['raw_name'] as String?)?.trim().isNotEmpty == true ? (data['raw_name'] as String).trim() : 'Unknown item');
    final quantity = (data['quantity'] as num?)?.toDouble() ?? 1.0;
    final unitPriceCents = data['unit_price'] is int ? data['unit_price'] as int : 0;
    final totalPriceCents = data['total_price'] is int ? data['total_price'] as int : 0;

    final isWholeNumber = quantity == quantity.truncateToDouble();
    final qtyStr = isWholeNumber ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
    final showQtyLine = quantity != 1.0 || unitPriceCents != totalPriceCents;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                if (showQtyLine) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$qtyStr × ${formatCents(unitPriceCents)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCents(totalPriceCents),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
