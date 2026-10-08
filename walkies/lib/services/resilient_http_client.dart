import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// HTTP client for all Supabase traffic.
///
/// Every request gets a time limit, so a weak signal produces an error the
/// UI can show instead of a spinner that never ends. Read-only requests
/// (GET/HEAD) are retried with a short back-off after a timeout or a
/// dropped connection; writes are never retried, so nothing is applied
/// twice.
class ResilientHttpClient extends http.BaseClient {
  ResilientHttpClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 15),
    this.retries = 2,
    this.backoff = const Duration(milliseconds: 600),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;
  final int retries;
  final Duration backoff;

  static bool _isRetryable(http.BaseRequest request) =>
      (request.method == 'GET' || request.method == 'HEAD') &&
      request is http.Request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isRetryable(request)) {
      return _inner.send(request).timeout(timeout);
    }

    final original = request as http.Request;
    var attempt = 0;
    while (true) {
      try {
        // A request can only be sent once, so each attempt sends a copy
        return await _inner.send(_copy(original)).timeout(timeout);
      } on TimeoutException {
        if (attempt >= retries) rethrow;
      } on SocketException {
        if (attempt >= retries) rethrow;
      } on http.ClientException {
        if (attempt >= retries) rethrow;
      }
      attempt++;
      await Future<void>.delayed(backoff * attempt);
    }
  }

  static http.Request _copy(http.Request request) {
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    if (request.bodyBytes.isNotEmpty) copy.bodyBytes = request.bodyBytes;
    return copy;
  }

  @override
  void close() => _inner.close();
}
