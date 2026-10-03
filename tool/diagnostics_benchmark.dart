import 'dart:convert';
import 'dart:io';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/diagnostics.dart';

// AOT adapter benchmark. No Flutter renderer, device, or production network claim.
final class _UnusedTransport implements DeliveryTransport {
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async => throw StateError('Manual benchmark must not request delivery.');
  @override
  void close() {}
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Pass repository root and output JSON path.');
  }
  final fixture =
      jsonDecode(
            File(
              '${arguments[0]}/test/sdk-protocol/delivery.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final bundle = TranslationBundle(
    fallbacks: {'en': null},
    entries: {
      'en': [
        TranslationEntry(
          key: 'plain',
          format: MessageFormat.plain,
          parameters: {},
          value: 'Available',
        ),
        TranslationEntry(
          key: 'icu',
          format: MessageFormat.icu,
          parameters: {'count': ParameterType.number},
          value: '{count, plural, one {One item} other {# items}}',
        ),
      ],
    },
  );
  final samples = <Map<String, Object>>[];
  final clock = Stopwatch()..start();
  for (final enabled in [false, true]) {
    final reporter = enabled
        ? SdkDiagnosticReporter(
            DiagnosticsConfig(
              endpoint: Uri.parse(
                'https://diagnostics.invalid/telemetry/v1/sdk-events',
              ),
              key: 'lsd_${List.filled(43, 'a').join()}',
            ),
            '1.0.0',
          )
        : null;
    final client = LocalisyncClient(
      config: LocalisyncConfig(
        projectId: fixture['projectId']! as String,
        distributionId: fixture['distributionId']! as String,
        channel: Channel.preview,
        addresses: [
          Uri.parse('https://primary.invalid'),
          Uri.parse('https://secondary.invalid'),
        ],
        readKey: 'test-read-key',
        trustedKeys: {'test-1': fixture['publicKey']! as String},
        appVersion: '1.0.0',
        bundled: bundle,
        locale: 'en',
        updatePolicy: UpdatePolicy.manual,
      ),
      transport: _UnusedTransport(),
      cache: MemoryDeliveryCache(),
      diagnostics: reporter,
    );
    reporter?.attach(client);
    await client.ready;
    for (final key in ['plain', 'icu']) {
      final parameters = key == 'icu'
          ? <String, Object>{'count': 3}
          : <String, Object>{};
      for (var i = 0; i < 5000; i++) {
        client.translate(key, arguments: parameters);
      }
      final values = <double>[];
      var characters = 0;
      final rss = ProcessInfo.currentRss;
      for (var i = 0; i < 20000; i++) {
        final before = clock.elapsedTicks;
        characters += client.translate(key, arguments: parameters).length;
        values.add((clock.elapsedTicks - before) * 1000000 / clock.frequency);
      }
      values.sort();
      samples.add({
        'enabled': enabled,
        'key': key,
        'n': values.length,
        'p95Us': values[(values.length * .95).floor()],
        'p99Us': values[(values.length * .99).floor()],
        'characters': characters,
        'rssBefore': rss,
        'rssAfter': ProcessInfo.currentRss,
      });
    }
    await client.dispose();
  }
  File(arguments[1]).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'date': DateTime.now().toUtc().toIso8601String(),
      'dart': Platform.version,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'mode': 'Dart AOT adapter on macOS; no Flutter renderer or device',
      'warmup': 5000,
      'samples': samples,
    }),
  );
}
