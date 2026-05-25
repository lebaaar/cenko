import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReceiptRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Increment whenever a receipt is saved.
/// Any provider that watches this will automatically re-fetch.
final receiptRevisionProvider =
    NotifierProvider<ReceiptRevisionNotifier, int>(ReceiptRevisionNotifier.new);
