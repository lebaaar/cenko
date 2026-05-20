const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _monthNamesSlovenian = [
  'januar',
  'februar',
  'marec',
  'april',
  'maj',
  'junij',
  'julij',
  'avgust',
  'september',
  'oktober',
  'november',
  'december',
];

String displayDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final month = date.month.toString().padLeft(1, '0');
  final day = date.day.toString().padLeft(1, '0');
  final year = date.year;
  return '$day.$month.$year';
}

String displayWordedDate(DateTime date, {String lang = 'en'}) {
  final month = lang == 'sl' ? _monthNamesSlovenian[date.month - 1] : _monthNames[date.month - 1];
  final day = date.day;
  final year = date.year;
  return '$day. $month $year';
}
