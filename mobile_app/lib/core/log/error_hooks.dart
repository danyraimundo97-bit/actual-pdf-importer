import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_log.dart';

const _log = AppLog('app');

/// Routes every uncaught error to the log, with its stack trace:
/// framework errors (build, layout, gestures) and uncaught async errors.
/// The previous handlers still run, so debug builds keep the red screen and
/// console dump.
void installGlobalErrorHandlers() {
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    _log.error(
      'Flutter error${details.context == null ? '' : ' ${details.context}'}',
      details.exception,
      details.stack,
      {if (details.library != null) 'library': details.library},
    );
    previousFlutter?.call(details);
  };

  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.error('Uncaught error', error, stack);
    // Flushed right away: this may be the last thing before a crash.
    Logs.flush();
    return previousPlatform?.call(error, stack) ?? false;
  };
}

/// Logs providers that fail (an exception in a provider's build), and, at
/// debug, provider disposal. Riverpod would otherwise surface these only as
/// an AsyncError on screen.
class LogProviderObserver extends ProviderObserver {
  const LogProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _log.error('Provider failed', error, stackTrace, {'provider': provider.name ?? provider.runtimeType.toString()});
  }
}

/// Debug-only navigation trail: which screen the user was on before a
/// problem.
class LogNavigatorObserver extends NavigatorObserver {
  static const _nav = AppLog('nav');

  String _name(Route<dynamic>? route) => route?.settings.name ?? route?.runtimeType.toString() ?? '-';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _nav.debug('push ${_name(route)}', {'from': _name(previousRoute)});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _nav.debug('pop ${_name(route)}', {'to': _name(previousRoute)});

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _nav.debug('replace ${_name(oldRoute)} -> ${_name(newRoute)}');
}

/// Startup line: build mode and platform.
void logAppStart() {
  final mode = kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
  _log.info('App started', {
    'mode': mode,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'debugLogging': Logs.debugEnabled,
  });
}
