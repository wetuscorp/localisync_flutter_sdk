import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/diagnostics.dart';

void main() {
  test(
    'opt-in reporter batches safe counters; retries are finite and dispose cancels',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <Map<String, Object?>>[];
      var fail = false;
      final sub = server.listen((request) async {
        received.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>,
        );
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          startsWith('Bearer lsd_'),
        );
        expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
        request.response.statusCode = fail ? 503 : 202;
        await request.response.close();
      });
      final config = DiagnosticsConfig(
        endpoint: Uri.parse(
          'http://127.0.0.1:${server.port}/telemetry/v1/sdk-events',
        ),
        key: 'lsd_${List.filled(43, 'a').join()}',
      );
      config.validate(true);
      final reporter = SdkDiagnosticReporter(config, '1.2.3+build');
      try {
        for (var i = 0; i < 2000; i++) {
          reporter.record(FailureCode.arguments, DiagnosticStage.translate);
        }
        expect(received, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        expect(received, hasLength(1));
        final events = received.first['events']! as List<Object?>;
        final event = events.single! as Map<String, Object?>;
        expect(event['count'], 2000);
        expect(event.keys.toSet(), {
          'id',
          'observedAt',
          'sdk',
          'sdkVersion',
          'appVersion',
          'code',
          'stage',
          'count',
        });
        fail = true;
        reporter.record(FailureCode.storage, DiagnosticStage.cache);
        await Future<void>.delayed(const Duration(milliseconds: 2000));
        expect(received, hasLength(3));
        reporter.record(FailureCode.network, DiagnosticStage.refresh);
        reporter.close();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(received, hasLength(3));
      } finally {
        reporter.close();
        await sub.cancel();
        await server.close(force: true);
      }
    },
  );
  test('diagnostics reject insecure or ambiguous scopes', () {
    for (final url in [
      'http://remote.invalid/telemetry/v1/sdk-events',
      'https://x.invalid/telemetry/v1/sdk-events?token=x',
    ]) {
      expect(
        () => DiagnosticsConfig(
          endpoint: Uri.parse(url),
          key: 'lsd_${List.filled(43, 'a').join()}',
        ).validate(false),
        throwsA(isA<LocalisyncException>()),
      );
    }
  });
}
