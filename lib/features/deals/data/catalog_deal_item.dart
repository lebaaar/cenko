import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogDealItem {
  final String id;
  final String productId;
  final String title;
  final String storeName;
  final int salePriceCents;
  final int? originalPriceCents;
  final int? discountPercent;
  final String? imageUrl;
  final DateTime? validUntil;

  const CatalogDealItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.storeName,
    required this.salePriceCents,
    this.originalPriceCents,
    this.discountPercent,
    this.imageUrl,
    this.validUntil,
  });

  int get savingsCents {
    final original = originalPriceCents;
    if (original == null) return 0;
    final diff = original - salePriceCents;
    return diff > 0 ? diff : 0;
  }

  factory CatalogDealItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = (data['name'] as String?)?.trim();
    final storeName = (data['store_name'] as String?)?.trim();
    final rawImage = (data['image_url'] as String?)?.trim();
    final validUntilTs = data['valid_until'] as Timestamp?;

    return CatalogDealItem(
      id: doc.id,
      productId: (data['product_id'] as String?) ?? doc.id,
      title: (name == null || name.isEmpty) ? 'Unknown product' : name,
      storeName: (storeName == null || storeName.isEmpty) ? 'Unknown store' : storeName,
      salePriceCents: data['sale_price'] as int? ?? 0,
      originalPriceCents: data['original_price'] as int?,
      discountPercent: data['discount_pct'] as int?,
      imageUrl: (rawImage == null || rawImage.isEmpty) ? null : rawImage,
      validUntil: validUntilTs?.toDate(),
    );
  }
}
