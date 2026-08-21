import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Wraps receive_sharing_intent's static API so a PDF shared from a bank
/// app or mail client can land straight in the Import screen (see the
/// intent filters added to AndroidManifest.xml).
///
/// IMPORTANT: this targets receive_sharing_intent ~1.8.x's API
/// (`ReceiveSharingIntent.instance.getInitialMedia()` /
/// `.getMediaStream()` / `.reset()`). This package's static surface has
/// changed across major versions in the past — if `flutter pub get`
/// resolves a different major version, check this file against that
/// version's README before assuming it still compiles.
class SharedPdf {
  final String path;
  final String filename;

  const SharedPdf({required this.path, required this.filename});
}

class ShareIntentService {
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// Call once at screen startup: picks up a PDF that launched the app via
  /// the share sheet (cold start), then clears it so it isn't redelivered.
  Future<SharedPdf?> takeInitial() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    final pdf = _firstPdf(media);
    if (pdf != null) {
      ReceiveSharingIntent.instance.reset();
    }
    return pdf;
  }

  /// Call once at screen startup: handles a PDF shared while the app is
  /// already running.
  void listen(void Function(SharedPdf pdf) onShared) {
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      final pdf = _firstPdf(media);
      if (pdf != null) onShared(pdf);
    });
  }

  SharedPdf? _firstPdf(List<SharedMediaFile> media) {
    for (final file in media) {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        return SharedPdf(path: file.path, filename: file.path.split('/').last);
      }
    }
    return null;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
