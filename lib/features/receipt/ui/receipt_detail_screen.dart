import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/core/utils/store_util.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/receipt_revision_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _receiptRowProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, ({String uid, String receiptId})>((ref, args) async {
  final row = await Supabase.instance.client
      .from('receipt')
      .select('id, total, receipt_date, scanned_at, store:store_id(name)')
      .eq('id', int.parse(args.receiptId))
      .eq('user_id', args.uid)
      .maybeSingle();
  return row;
});

final _receiptItemsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String uid, String receiptId})>((ref, args) async {
  final rows = await Supabase.instance.client
      .from('receipt_item')
      .select('id, name, quantity, unit_price, total_price')
      .eq('receipt_id', int.parse(args.receiptId))
      .order('total_price', ascending: false);
  return (rows as List).map((r) => r as Map<String, dynamic>).toList();
});

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.user.id;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final args = (uid: uid, receiptId: receiptId);
    final receiptAsync = ref.watch(_receiptRowProvider(args));
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
      data: (row) {
        if (row == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.receiptTitle),
              leading: BackButton(onPressed: () => context.pop()),
            ),
            body: Center(child: Text(AppLocalizations.of(context)!.receiptNotFound)),
          );
        }

        final storeMap = row['store'] as Map<String, dynamic>?;
        final storeName = _parseStoreName(storeMap);
        final date = _parseDate(row['receipt_date']);
        final scannedAt = _parseDate(row['scanned_at']);
        final totalPriceCents = row['total'] is int ? row['total'] as int : 0;

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
                _ReceiptHeaderCard(
                    storeName: storeName, date: date, scannedAt: scannedAt, totalPriceCents: totalPriceCents),
                const SizedBox(height: 12),
                _ItemsCard(itemsAsync: itemsAsync, uid: uid, receiptId: receiptId),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _parseStoreName(Map<String, dynamic>? storeMap) {
  final s = (storeMap?['name'] as String?)?.trim();
  return s == null || s.isEmpty ? 'Unknown store' : s;
}

DateTime _parseDate(dynamic value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.now();
}

String _timeLabel(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _ReceiptHeaderCard extends StatelessWidget {
  const _ReceiptHeaderCard(
      {required this.storeName, required this.date, required this.scannedAt, required this.totalPriceCents});

  final String storeName;
  final DateTime date;
  final DateTime scannedAt;
  final int totalPriceCents;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoAsset = storeLogoAsset(storeName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
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
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!
                      .receiptScanned(displayWordedDate(scannedAt), _timeLabel(scannedAt)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCents(totalPriceCents),
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends ConsumerWidget {
  const _ItemsCard({required this.itemsAsync, required this.uid, required this.receiptId});

  final AsyncValue<List<Map<String, dynamic>>> itemsAsync;
  final String uid;
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: itemsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          'Failed to load items: ${e.toString().replaceFirst('Exception: ', '')}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.receiptItemsHeader(items.length),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(letterSpacing: 1.2, color: colorScheme.onSurfaceVariant),
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context)!.receiptNoItems,
                    style: Theme.of(context).textTheme.bodyMedium),
              ] else ...[
                const SizedBox(height: 4),
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.15), height: 1),
                  _ItemRow(
                    itemId: items[i]['id'].toString(),
                    data: items[i],
                    uid: uid,
                    receiptId: receiptId,
                  ),
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
  const _ItemRow({required this.itemId, required this.data, required this.uid, required this.receiptId});

  final String itemId;
  final Map<String, dynamic> data;
  final String uid;
  final String receiptId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'Unknown item';
    final quantity = (data['quantity'] as num?)?.toDouble() ?? 1.0;
    final unitPriceCents = data['unit_price'] is int ? data['unit_price'] as int : 0;
    final totalPriceCents = data['total_price'] is int ? data['total_price'] as int : 0;

    final isWholeNumber = quantity == quantity.truncateToDouble();
    final qtyStr =
        isWholeNumber ? quantity.toInt().toString() : quantity.toStringAsFixed(2);

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _EditItemSheet(
          uid: uid,
          receiptId: receiptId,
          itemId: itemId,
          name: name,
          unitPriceCents: unitPriceCents,
          quantity: quantity,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$qtyStr × ${formatCents(unitPriceCents)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatCents(totalPriceCents),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({
    required this.uid,
    required this.receiptId,
    required this.itemId,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
  });

  final String uid;
  final String receiptId;
  final String itemId;
  final String name;
  final int unitPriceCents;
  final double quantity;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _priceCtrl = TextEditingController(text: _centsToString(widget.unitPriceCents));
    _qtyCtrl = TextEditingController(text: _qtyToString(widget.quantity));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _centsToString(int cents) => (cents / 100).toStringAsFixed(2);

  String _qtyToString(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  int _parseCents(String s) {
    final v = double.tryParse(s.replaceAll(',', '.')) ?? 0;
    return (v * 100).round();
  }

  double _parseQty(String s) => double.tryParse(s.replaceAll(',', '.')) ?? widget.quantity;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _formError = null;
    });

    final supabase = Supabase.instance.client;
    final name = _nameCtrl.text.trim();
    final unitPriceCents = _parseCents(_priceCtrl.text);
    final quantity = widget.quantity > 1 ? _parseQty(_qtyCtrl.text) : widget.quantity;
    final totalPriceCents = (quantity * unitPriceCents).round();
    final receiptIdInt = int.parse(widget.receiptId);

    try {
      await supabase.from('receipt_item').update({
        'name': name,
        'unit_price': unitPriceCents,
        'quantity': quantity.round(),
        'total_price': totalPriceCents,
      }).eq('id', int.parse(widget.itemId));

      // Recompute receipt total from items
      final itemRows = await supabase
          .from('receipt_item')
          .select('total_price')
          .eq('receipt_id', receiptIdInt);
      final newTotal = (itemRows as List).fold<int>(
          0, (acc, r) => acc + (r['total_price'] is int ? r['total_price'] as int : 0));
      await supabase
          .from('receipt')
          .update({'total': newTotal})
          .eq('id', receiptIdInt)
          .eq('user_id', widget.uid);

      final args = (uid: widget.uid, receiptId: widget.receiptId);
      ref.invalidate(_receiptItemsProvider(args));
      ref.invalidate(_receiptRowProvider(args));
      ref.read(receiptRevisionProvider.notifier).increment();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = 'Failed to save: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.viewPaddingOf(context).bottom +
              20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.receiptEditItemTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.receiptEditItemSubtitle,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (_formError != null) ...[
              Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(labelText: AppLocalizations.of(context)!.listItemName),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppLocalizations.of(context)!.listItemNameRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              textInputAction:
                  widget.quantity > 1 ? TextInputAction.next : TextInputAction.done,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: AppLocalizations.of(context)!.receiptUnitPrice),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return AppLocalizations.of(context)!.receiptPriceRequired;
                if (double.tryParse(v.replaceAll(',', '.')) == null)
                  return AppLocalizations.of(context)!.receiptInvalidPrice;
                return null;
              },
            ),
            if (widget.quantity > 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: AppLocalizations.of(context)!.listQuantity),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return AppLocalizations.of(context)!.receiptQuantityRequired;
                  if (double.tryParse(v.replaceAll(',', '.')) == null)
                    return AppLocalizations.of(context)!.receiptInvalidQuantity;
                  return null;
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(context)!.saveChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
