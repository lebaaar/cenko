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

  /// Constructs from a Supabase `product` row (with embedded `store:store_id(name)`).
  factory CatalogDealItem.fromMap(Map<String, dynamic> m) {
    final storeMap = m['store'] as Map<String, dynamic>?;
    final storeName = _normalizedStoreName(storeMap?['name'] as String? ?? 'Unknown store');
    final originalPrice = _intValue(m['original_price']) ?? 0;
    final salePrice = _intValue(m['sale_price']) ?? 0;
    final discountPercent = _intValue(m['discount_pct']) ??
        _derivedDiscountPercent(originalPrice: originalPrice, salePrice: salePrice);

    return CatalogDealItem(
      id: m['id'].toString(),
      productId: m['id'].toString(),
      scrapedFromUrl: '',
      productName: m['name'] as String? ?? 'Unknown product',
      storeName: storeName,
      brand: null,
      category: null,
      imageUrl: m['image_url'] as String?,
      originalPrice: originalPrice,
      salePrice: salePrice,
      discountPercent: discountPercent,
      validFrom: _dateValue(m['valid_from']),
      validUntil: _dateValue(m['valid_to']),
      scrapedAt: _dateValue(m['scraped_at']),
    );
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return null;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  static String _normalizedStoreName(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == 'tus_drogrija') return 'tus_drogerija';
    return normalized;
  }

  static int? _derivedDiscountPercent({required int originalPrice, required int salePrice}) {
    if (originalPrice <= 0 || salePrice >= originalPrice) return null;
    return (((originalPrice - salePrice) / originalPrice) * 100).round();
  }
}
