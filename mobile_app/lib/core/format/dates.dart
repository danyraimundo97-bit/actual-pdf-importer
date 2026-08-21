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
