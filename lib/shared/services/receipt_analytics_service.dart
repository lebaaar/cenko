import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptAnalyticsService {
  ReceiptAnalyticsService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int commonBoughtProductWindowDays = 90;
  static const int commonBoughtProductInactivityDays = 45;
  static const int commonBoughtProductMinPurchases = 4;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _users() => _firestore.collection('users');

  Future<void> deleteReceiptAndResyncCommonProducts({required String uid, required String receiptId}) async {
    final receiptRef = _users().doc(uid).collection('receipts').doc(receiptId);
    final itemsSnapshot = await receiptRef.collection('items').get();

    await _deleteDocuments(itemsSnapshot.docs.map((doc) => doc.reference).toList(growable: false));
    await receiptRef.delete();
    await syncCommonBoughtProducts(uid: uid);
  }

  Future<void> syncCommonBoughtProducts({required String uid}) async {
    final userRef = _users().doc(uid);
    final receiptsRef = userRef.collection('receipts');
    final commonProductsRef = userRef.collection('common_products');

    final now = DateTime.now().toUtc();
    final recentReceiptCutoff = now.subtract(const Duration(days: commonBoughtProductWindowDays));
    final inactiveCutoff = now.subtract(const Duration(days: commonBoughtProductInactivityDays));

    final recentReceiptsSnapshot = await receiptsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(recentReceiptCutoff))
        .orderBy('date', descending: true)
        .get();
    final productStatsByKey = <String, _CommonBoughtProductStats>{};

    for (final receiptDoc in recentReceiptsSnapshot.docs) {
      final receiptData = receiptDoc.data();
      final receiptDate = _dateFromReceipt(receiptData);
      final receiptItemsSnapshot = await receiptDoc.reference.collection('items').get();
      final keysSeenInReceipt = <String>{};

      for (final itemDoc in receiptItemsSnapshot.docs) {
        final rawName = _asString(itemDoc.data()['raw_name']);
        final productKey = _normalizeCommonProductKey(rawName);
        if (productKey.isEmpty || !keysSeenInReceipt.add(productKey)) {
          continue;
        }

        final stats = productStatsByKey.putIfAbsent(productKey, () => _CommonBoughtProductStats(name: rawName, lastPurchasedAt: receiptDate));
        stats.recordPurchase(candidateName: rawName, purchasedAt: receiptDate);
      }
    }

    final existingCommonProductsSnapshot = await commonProductsRef.get();
    final activeKeys = <String>{};
    final batch = _firestore.batch();

    for (final entry in productStatsByKey.entries) {
      final productKey = entry.key;
      final stats = entry.value;
      final qualifies = stats.purchaseCount >= commonBoughtProductMinPurchases && !stats.lastPurchasedAt.isBefore(inactiveCutoff);
      final docRef = commonProductsRef.doc(productKey);

      if (!qualifies) {
        continue;
      }

      activeKeys.add(productKey);
      batch.set(docRef, {
        'item_id': productKey,
        'name': stats.name,
        'brand': null,
        'image_url': null,
        'purchase_count': stats.purchaseCount,
        'last_purchased_at': Timestamp.fromDate(stats.lastPurchasedAt),
        'added_at': Timestamp.fromDate(stats.lastPurchasedAt),
      }, SetOptions(merge: true));
    }

    for (final doc in existingCommonProductsSnapshot.docs) {
      if (activeKeys.contains(doc.id)) {
        continue;
      }
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> _deleteDocuments(List<DocumentReference<Map<String, dynamic>>> documents) async {
    if (documents.isEmpty) {
      return;
    }

    const chunkSize = 450;
    for (var index = 0; index < documents.length; index += chunkSize) {
      final batch = _firestore.batch();
      final chunk = documents.skip(index).take(chunkSize);
      for (final document in chunk) {
        batch.delete(document);
      }
      await batch.commit();
    }
  }

  DateTime _dateFromReceipt(Map<String, dynamic> receiptData) {
    final value = receiptData['date'];
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    final parsed = DateTime.tryParse(_asString(value));
    return parsed?.toUtc() ?? DateTime.now().toUtc();
  }

  String _normalizeCommonProductKey(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceAll(' ', '_');
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      return value.trim();
    }

    return value.toString().trim();
  }
}

class _CommonBoughtProductStats {
  _CommonBoughtProductStats({required this.name, required this.lastPurchasedAt}) : purchaseCount = 0;

  String name;
  DateTime lastPurchasedAt;
  int purchaseCount;

  void recordPurchase({required String candidateName, required DateTime purchasedAt}) {
    purchaseCount += 1;

    if (purchasedAt.isAfter(lastPurchasedAt)) {
      lastPurchasedAt = purchasedAt;
      name = candidateName;
    }
  }
}
