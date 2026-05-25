import 'package:supabase_flutter/supabase_flutter.dart';

class ReceiptAnalyticsService {
  final _client = Supabase.instance.client;

  /// Deletes a receipt row — receipt_items cascade via FK on delete.
  Future<void> deleteReceiptAndResyncCommonProducts({required String uid, required String receiptId}) async {
    await _client.from('receipt').delete().eq('id', int.parse(receiptId)).eq('user_id', uid);
  }

  /// TODO - v2
  Future<void> syncCommonBoughtProducts({required String uid}) async {}
}
