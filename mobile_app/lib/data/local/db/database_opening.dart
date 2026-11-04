import 'dart:math';

/// What happened to the database file before drift opened it.
enum DatabaseOpening {
  /// No file yet: drift creates it, encrypted from the first write.
  created,

  /// An encrypted file the key opens.
  opened,

  /// A plain file from before encryption, now encrypted in place.
  encrypted,

  /// The key doesn't open the file (secure storage was cleared, or the
  /// file came from another phone). It was set aside as
  /// `<name>.unreadable` and the app starts with an empty database.
  reset,
}

/// A new random database key: 32 bytes as 64 hex characters.
String newDatabaseKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
