import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:walkies/services/resilient_http_client.dart';

void main() {
  ResilientHttpClient client(MockClientHandler handler) => ResilientHttpClient(
        inner: MockClient(handler),
        timeout: const Duration(milliseconds: 50),
        backoff: Duration.zero,
      );

  test('retries a GET after a dropped connection', () async {
    var calls = 0;
    final c = client((request) async {
      calls++;
      if (calls < 3) throw http.ClientException('connection reset');
      return http.Response('ok', 200);
    });
    final response = await c.get(Uri.parse('https://example.org/rest/v1/x'));
    expect(response.body, 'ok');
    expect(calls, 3);
  });

  test('times out a GET that never answers, after retrying', () async {
    var calls = 0;
    final c = client((request) {
      calls++;
      return Completer<http.Response>().future; // never completes
    });
    await expectLater(
      c.get(Uri.parse('https://example.org/rest/v1/x')),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 3); // first try + 2 retries
  });

  test('never retries a write', () async {
    var calls = 0;
    final c = client((request) async {
      calls++;
      throw http.ClientException('connection reset');
    });
    await expectLater(
      c.post(Uri.parse('https://example.org/rest/v1/x'), body: '{}'),
      throwsA(isA<http.ClientException>()),
    );
    expect(calls, 1);
  });

  test('times out a write without retrying', () async {
    var calls = 0;
    final c = client((request) {
      calls++;
      return Completer<http.Response>().future;
    });
    await expectLater(
      c.post(Uri.parse('https://example.org/rest/v1/x'), body: '{}'),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
  });
}
