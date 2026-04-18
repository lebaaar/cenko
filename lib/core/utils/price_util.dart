String formatCents(int cents) {
  final euros = cents ~/ 100;
  final remainder = (cents % 100).abs().toString().padLeft(2, '0');
  return '$euros.$remainder €';
}
