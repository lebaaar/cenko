class PersonalizedDealCardItem {
  final String id;
  final String title;
  final String storeName;
  final int currentPriceCents;
  final int? previousPriceCents;
  final int? discountPercent;
  final String? imageUrl;
  final DateTime? validUntil;

  const PersonalizedDealCardItem({
    required this.id,
    required this.title,
    required this.storeName,
    required this.currentPriceCents,
    this.previousPriceCents,
    this.discountPercent,
    this.imageUrl,
    this.validUntil,
  });

  int get savingsCents {
    final previous = previousPriceCents;
    if (previous == null) return 0;
    final diff = previous - currentPriceCents;
    return diff > 0 ? diff : 0;
  }

  bool get hasDiscount => (discountPercent ?? 0) > 0;
}
