/// dd/MM/yyyy for display — never show the wire's ISO format to the user.
/// Written out manually rather than via intl's DateFormat so it works
/// without any locale-data initialization.
String formatDisplayDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// yyyy-MM-dd for the wire — what the backend sends and expects back.
String toIsoDate(DateTime date) {
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(date.year, 4)}-${pad(date.month, 2)}-${pad(date.day, 2)}';
}

const _months = [
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

/// "November 2026" for `YYYY-MM`.
String monthLabel(String yyyyMm) => '${_months[int.parse(yyyyMm.substring(5, 7)) - 1]} ${yyyyMm.substring(0, 4)}';

/// "Today", "Yesterday", or the date, for a list's day headers.
String dayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (same(date, today)) return 'Today';
  if (same(date, DateTime(today.year, today.month, today.day - 1))) return 'Yesterday';
  return formatDisplayDate(date);
}
