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
  if (s.contains('tus') && s.contains('droger')) return 'assets/images/tus-drogerija.jpg';
  if (s.contains('tus') || s.contains('tuš')) return 'assets/images/tus.png';
  if (s.contains('spar')) return 'assets/images/spar.png';
  if (s.contains('mercator')) return 'assets/images/mercator.webp';
  if (s.contains('hofer')) return 'assets/images/hofer.png';
  if (s.contains('lidl')) return 'assets/images/lidl.png';
  if (s.contains('eurospin')) return 'assets/images/eurospin.png';
  return null;
}
