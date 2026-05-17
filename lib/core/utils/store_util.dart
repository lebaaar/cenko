String storeDisplayName(String storeName) {
  switch (storeName.toLowerCase()) {
    case 'tus_drogerija':
    case 'tus_drogrija':
      return 'Tuš drogerija';
    case 'tus':
      return 'Tuš';
    case 'spar':
      return 'Spar';
    case 'mercator':
      return 'Mercator';
    case 'lidl':
      return 'Lidl';
    case 'hofer':
      return 'Hofer';
    case 'eurospin':
      return 'Eurospin';
    default:
      return storeName;
  }
}

String? storeLogoAsset(String storeName) {
  final s = storeName.toLowerCase();
  if (s.contains('tus') && s.contains('droger')) return 'assets/stores/tus-drogerija.jpg';
  if (s.contains('tus') || s.contains('tuš')) return 'assets/stores/tus.png';
  if (s.contains('spar')) return 'assets/stores/spar.png';
  if (s.contains('mercator')) return 'assets/stores/mercator.webp';
  if (s.contains('hofer')) return 'assets/stores/hofer.png';
  if (s.contains('lidl')) return 'assets/stores/lidl.png';
  if (s.contains('eurospin')) return 'assets/stores/eurospin.png';
  return null;
}
