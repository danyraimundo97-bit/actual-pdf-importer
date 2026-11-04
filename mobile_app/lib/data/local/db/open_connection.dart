// The app database's connection: encrypted on native platforms
// (open_connection_native.dart), drift_flutter's default on the web.
export 'open_connection_native.dart' if (dart.library.js_interop) 'open_connection_web.dart';
