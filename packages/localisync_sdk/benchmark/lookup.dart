import 'dart:convert';
import 'dart:io';
import 'package:localisync_sdk/core.dart';

Map<String, num> measure(String Function() read) {
  var sink = 0;
  for (var i = 0; i < 5000; i++) {
    sink += read().length;
  }
  final samples = <double>[];
  for (var batch = 0; batch < 20000; batch++) {
    final watch = Stopwatch()..start();
    sink += read().length;
    watch.stop();
    samples.add(watch.elapsedTicks * 1000000 / watch.frequency);
  }
  samples.sort();
  return {
    'p50Micros': samples[10000],
    'p95Micros': samples[19000],
    'p99Micros': samples[19800],
    'checksum': sink,
  };
}

Future<void> main(List<String> args) async {
  final limit = args.contains('--limit'), length = limit ? 1800 : 128;
  final icuHeavy = args.contains('--icu');
  final before = ProcessInfo.currentRss;
  final start = Stopwatch()..start();
  final entries = <String, List<TranslationEntry>>{};
  final fallbacks = <String, String?>{
    'en': null,
    'tr': 'en',
    'fr': 'en',
    'de': 'en',
    'ar': 'en',
  };
  for (final locale in fallbacks.keys) {
    entries[locale] = List.generate(
      10000,
      (index) => TranslationEntry(
        key: 'key_$index',
        format: index == 0 || icuHeavy
            ? MessageFormat.icu
            : MessageFormat.plain,
        parameters: index == 0 || icuHeavy
            ? {'count': ParameterType.number}
            : {},
        value: index == 0 || icuHeavy
            ? '{count, plural, one {# item} other {# items}}'
            : List.filled(length, 'a').join(),
      ),
    );
  }
  final fixtureMs = start.elapsedMicroseconds / 1000;
  start.reset();
  final bundle = TranslationBundle(fallbacks: fallbacks, entries: entries);
  start.stop();
  final message = bundle.find('en', 'key_1')!.$1;
  final icu = bundle.find('en', 'key_0')!.$1;
  final client = LocalisyncClient(
    config: LocalisyncConfig(
      projectId: '10000000-0000-4000-8000-000000000001',
      distributionId: '20000000-0000-4000-8000-000000000001',
      channel: Channel.preview,
      addresses: [
        Uri.parse('https://primary.invalid'),
        Uri.parse('https://secondary.invalid'),
      ],
      readKey: 'benchmark-only',
      trustedKeys: {'test-1': '6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw='},
      appVersion: '1.0.0',
      bundled: bundle,
      locale: 'en',
      updatePolicy: UpdatePolicy.manual,
    ),
    transport: _NoNetwork(),
    cache: MemoryDeliveryCache(),
  );
  await client.ready;
  final document = utf8.encode(
    jsonEncode(
      entries.map(
        (locale, items) =>
            MapEntry(locale, items.map((e) => e.toJson()).toList()),
      ),
    ),
  );
  final hash = Stopwatch()..start();
  await sha256Hex(document);
  hash.stop();
  final report = {
    'runtime': Platform.version,
    'os': Platform.operatingSystem,
    'mode': 'Dart AOT executable',
    'keys': 10000,
    'values': 50000,
    'contentBytes': document.length,
    'fixtureMs': fixtureMs,
    'prepareMs': start.elapsedMicroseconds / 1000,
    'sha256Ms': hash.elapsedMicroseconds / 1000,
    'rssGrowthBytes': ProcessInfo.currentRss - before,
    'maxRssBytes': ProcessInfo.maxRss,
    'icuValues': icuHeavy ? 50000 : 5,
    if (!icuHeavy) 'plain': measure(() => message.format({})),
    'icu': measure(() => icu.format({'count': 22})),
    if (!icuHeavy) 'clientPlain': measure(() => client.translate('key_1')),
    'clientIcu': measure(
      () => client.translate('key_0', arguments: {'count': 22}),
    ),
  };
  stdout.writeln(jsonEncode(report));
  await client.dispose();
}

class _NoNetwork implements DeliveryTransport {
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) => throw StateError('Benchmark must not use network.');
  @override
  void close() {}
}
