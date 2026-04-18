String displayDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final year = date.year;
  return '$day.$month.$year';
}
