import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogDealItem {
  final String id;
  final String productId;
  final String scrapedFromUrl;
  final String productName;
  final String storeName;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final int originalPrice;
  final int salePrice;
  final int? discountPercent;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? scrapedAt;

  const CatalogDealItem({
    required this.id,
    required this.productId,
    required this.scrapedFromUrl,
    required this.productName,
    required this.storeName,
    this.brand,
    this.category,
    this.imageUrl,
    required this.originalPrice,
    required this.salePrice,
    this.discountPercent,
    this.validFrom,
    this.validUntil,
    this.scrapedAt,
  });

  String get title => productName;

  int get salePriceCents => salePrice;

  int? get originalPriceCents => originalPrice;

  int get savingsCents {
    final diff = originalPrice - salePrice;
    return diff > 0 ? diff : 0;
  }

  bool get isActive {
    final now = DateTime.now();
    final from = validFrom;
    final until = validUntil;
    if (from != null && now.isBefore(from)) return false;
    if (until != null && now.isAfter(until)) return false;
    return true;
  }

  factory CatalogDealItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final productName = _stringValue(data['product_name']) ?? _stringValue(data['name']) ?? 'Unknown product';
    final storeName = _normalizedStoreName(_stringValue(data['store_name']) ?? 'Unknown store');
    final scrapedFromUrl = _stringValue(data['scraped_from_url']) ?? '';
    final brand = _stringValue(data['brand']);
    final category = _stringValue(data['category']);
    final rawImage = _stringValue(data['image_url']) ?? _stringValue(data['image']);
    final originalPrice = _intValue(data['original_price']) ?? 0;
    final salePrice = _intValue(data['sale_price']) ?? 0;
    final discountPercent = _intValue(data['discount_pct']) ?? _derivedDiscountPercent(originalPrice: originalPrice, salePrice: salePrice);

    return CatalogDealItem(
      id: doc.id,
      productId: (data['product_id'] as String?) ?? doc.id,
      scrapedFromUrl: scrapedFromUrl,
      productName: productName,
      storeName: storeName,
      brand: brand,
      category: category,
      imageUrl: rawImage,
      originalPrice: originalPrice,
      salePrice: salePrice,
      discountPercent: discountPercent,
      validFrom: _dateValue(data['valid_from']),
      validUntil: _dateValue(data['valid_until']),
      scrapedAt: _dateValue(data['scraped_at']),
    );
  }

  static String? _stringValue(dynamic value) {
    final stringValue = value is String ? value.trim() : null;
    return stringValue == null || stringValue.isEmpty ? null : stringValue;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return null;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _normalizedStoreName(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == 'tus_drogrija') {
      return 'tus_drogerija';
    }
    return normalized;
  }

  static int? _derivedDiscountPercent({required int originalPrice, required int salePrice}) {
    if (originalPrice <= 0 || salePrice >= originalPrice) return null;
    return (((originalPrice - salePrice) / originalPrice) * 100).round();
  }
}
