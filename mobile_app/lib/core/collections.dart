/// A tiny stand-in for package:collection's firstWhereOrNull, to avoid
/// pulling in a whole extra dependency for one helper.
T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
