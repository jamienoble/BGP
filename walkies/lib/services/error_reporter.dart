import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash and error reporting through Sentry.
///
/// Off unless the app is built with a DSN:
///   flutter build apk --dart-define=SENTRY_DSN=https://...@....ingest.de.sentry.io/...
///
/// Privacy: no user identity, IP address, screenshots or request bodies are
/// sent, only the error, its stack trace and a short note of where it
/// happened. Walkies handles health information, so keep it that way.
class ErrorReporter {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static const _environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'production');

  static bool get enabled => _dsn.isNotEmpty;

  /// Starts the app, wrapped in Sentry when it is configured. Sentry then
  /// also captures uncaught Flutter, Dart and native Android crashes.
  static Future<void> runApp(FutureOr<void> Function() appRunner) async {
    if (!enabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        options.sendDefaultPii = false;
        options.attachScreenshot = false;
        options.tracesSampleRate = 0.1;
        options.beforeSend = (event, hint) {
          event.user = null;
          return event;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Record an error that was caught and handled. Expected network
  /// failures (offline, timeouts) are logged locally only, so the report
  /// list shows real faults rather than bad signal.
  static void report(Object error, StackTrace? stack, {String? context}) {
    debugPrint('${context ?? 'Error'}: $error');
    if (!enabled || isNetworkError(error)) return;
    Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: context == null ? null : (scope) => scope.setTag('where', context),
    );
  }

  static bool isNetworkError(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException;
}
