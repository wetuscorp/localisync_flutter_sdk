import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:localisync_sdk/core.dart';
import 'package:test/test.dart';

late Map<String, Object?> fixture;
String field(String key) => fixture[key]! as String;
Map<String, String> get files => (fixture['files']! as Map<String, Object?>)
    .map((k, v) => MapEntry(k, v! as String));
TranslationEntry entry(
  String key,
  String? value, {
  Map<String, ParameterType> parameters = const {},
}) => TranslationEntry(
  key: key,
  format: parameters.isEmpty ? MessageFormat.plain : MessageFormat.icu,
  parameters: parameters,
  value: value,
);
TranslationBundle get baseline => TranslationBundle(
  fallbacks: {'en': null, 'tr': 'en'},
  entries: {
    'en': [
      entry('plain', 'Bundled text'),
      entry('fallback', 'Bundled fallback'),
    ],
    'tr': [],
  },
);
LocalisyncConfig config({
  UpdatePolicy update = UpdatePolicy.onStart,
  ActivationPolicy activation = ActivationPolicy.immediate,
  String version = '1.0.0',
  String locale = 'tr',
  Duration timeout = const Duration(seconds: 15),
  Duration total = const Duration(seconds: 60),
}) => LocalisyncConfig(
  projectId: field('projectId'),
  distributionId: field('distributionId'),
  channel: Channel.preview,
  addresses: [
    Uri.parse('https://primary.invalid'),
    Uri.parse('https://secondary.invalid'),
  ],
  readKey: 'test-read-key',
  trustedKeys: {'test-1': field('publicKey')},
  appVersion: version,
  bundled: baseline,
  locale: locale,
  updatePolicy: update,
  activationPolicy: activation,
  requestTimeout: timeout,
  refreshTimeout: total,
);

class FixtureTransport implements DeliveryTransport {
  String? catalog;
  int requests = 0;
  bool offline = false,
      primaryOffline = false,
      corrupt = false,
      notModified = false;
  Duration delay = Duration.zero;
  final paths = <String>[];
  @override
  Future<DeliveryResponse> get(
    Uri uri, {
    required String readKey,
    required int maxBytes,
    required Duration timeout,
    required Cancellation cancellation,
    String? etag,
  }) async {
    requests++;
    paths.add(uri.toString());
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    cancellation.check();
    if (offline || primaryOffline && uri.host == 'primary.invalid')
      throw const LocalisyncException(FailureCode.network, 'Offline fixture.');
    String value;
    if (uri.path.endsWith('/manifest') && !uri.path.contains('/releases/')) {
      if (notModified && etag != null) return DeliveryResponse(304, []);
      value = catalog ?? field('catalogJws');
    } else if (uri.path.endsWith('/manifest')) {
      value = field('manifestJws');
    } else {
      value = files[uri.pathSegments.last] ?? '';
      if (corrupt) value += 'x';
    }
    return DeliveryResponse(200, utf8.encode(value));
  }

  @override
  void close() {}
}

class FailingCache implements DeliveryCache {
  @override
  Future<CacheState?> read(String scope) async =>
      throw const LocalisyncException(FailureCode.storage, 'Unavailable.');
  @override
  Future<bool> write(
    String scope,
    CacheState state, {
    required int revision,
    required String catalogDigest,
    required int maxBytes,
    Cancellation? cancellation,
  }) async => throw const LocalisyncException(FailureCode.storage, 'Full.');
  @override
  Future<void> close() async {}
}

void main() {
  test(
    'prepared ICU formatters remain independent across messages and bundles',
    () {
      TranslationBundle bundle(String locale) => TranslationBundle(
        fallbacks: {locale: null},
        entries: {
          locale: [
            for (final key in ['first', 'second'])
              entry(
                key,
                '{count, plural, other {#}}',
                parameters: {'count': ParameterType.number},
              ),
          ],
        },
      );
      final english = bundle('en'), turkish = bundle('tr');
      for (var i = 0; i < 10; i++) {
        expect(
          english.find('en', 'first')!.$1.format({'count': 1234.5}),
          '1,234.5',
        );
        expect(
          turkish.find('tr', 'first')!.$1.format({'count': 1234.5}),
          '1.234,5',
        );
        expect(english.find('en', 'second')!.$1.format({'count': 2}), '2');
        expect(turkish.find('tr', 'second')!.$1.format({'count': 3}), '3');
      }
    },
  );
  setUpAll(() {
    fixture =
        jsonDecode(
              File(
                File('../../test/sdk-protocol/delivery.json').existsSync()
                    ? '../../test/sdk-protocol/delivery.json'
                    : '../../../../test/sdk-protocol/delivery.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test('strict SemVer agrees with server metadata and prerelease bounds', () {
    for (final item in fixture['versions']! as List<Object?>) {
      final d = item! as Map<String, Object?>;
      expect(
        Compatibility.fromJson(
          d['bounds'],
        ).accepts(AppVersion(d['version']! as String)),
        d['compatible'],
      );
    }
    for (final v in ['01.2.3', '1.0', ' 1.0.0', 'v1.0.0', '1.0.0-01']) {
      expect(() => AppVersion(v), throwsA(isA<LocalisyncException>()));
    }
  });
  test('invalid application configuration fails before starting delivery', () {
    for (final create in [
      () => config(locale: 'en-US-u-ca-gregory'),
      () => config(version: '9007199254740992.0.0'),
      () => config(timeout: Duration.zero),
    ]) {
      expect(
        create,
        throwsA(
          isA<LocalisyncException>().having(
            (error) => error.code,
            'code',
            FailureCode.configuration,
          ),
        ),
      );
    }
  });
  test('rejects duplicate JSON properties and excessive nesting', () async {
    await expectLater(
      decodeDocument('{"x":1,"x":2}'),
      throwsA(isA<LocalisyncException>()),
    );
    await expectLater(
      decodeDocument('${'[' * 65}0${']' * 65}'),
      throwsA(isA<LocalisyncException>()),
    );
    expect(await decodeDocument('{"s":"x\\\"y","n":1.5,"a":[true,null]}'), {
      's': 'x"y',
      'n': 1.5,
      'a': [true, null],
    });
  });
  test(
    'verifies Node JOSE and rejects tampering and unknown signing key',
    () async {
      final verifier = SignatureVerifier({'test-1': field('publicKey')});
      expect(
        Catalog.fromJson(
          await verifier.verify(
            field('catalogJws'),
            maxPayloadBytes: DeliveryLimits.catalog,
          ),
        ).revision,
        1,
      );
      await expectLater(
        verifier.verify(
          field('catalogJws').replaceFirst('.', '.a'),
          maxPayloadBytes: DeliveryLimits.catalog,
        ),
        throwsA(isA<LocalisyncException>()),
      );
      await expectLater(
        SignatureVerifier({
          'other': field('publicKey'),
        }).verify(field('catalogJws'), maxPayloadBytes: DeliveryLimits.catalog),
        throwsA(isA<LocalisyncException>()),
      );
    },
  );
  test(
    'baseline is synchronous and complete verified release activates',
    () async {
      final transport = FixtureTransport(),
          client = LocalisyncClient(
            config: config(),
            transport: transport,
            cache: MemoryDeliveryCache(),
          );
      expect(client.translate('plain'), 'Bundled text');
      expect((await client.ready).outcome, UpdateOutcome.updated);
      expect(
        client.translate('greeting', arguments: {'name': 'Ada'}),
        'Merhaba Ada',
      );
      expect(client.translate('basket', arguments: {'count': 2}), '2 items');
      expect(
        client.resolve('basket', arguments: {'count': 2}).resolvedLocale,
        'en',
      );
      expect(client.translate('rank', arguments: {'count': 22}), '22nd');
      expect(
        client.translate('empty', defaultValue: 'Application default'),
        'Application default',
      );
      expect(transport.requests, 4);
      await client.dispose();
    },
  );
  test('startup requests coalesce without later polling', () async {
    final transport = FixtureTransport()
          ..delay = const Duration(milliseconds: 2),
        client = LocalisyncClient(
          config: config(),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await Future.wait([client.ready, client.refresh(), client.refresh()]);
    final count = transport.requests;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(transport.requests, count);
    expect(count, 4);
    await client.dispose();
  });
  test(
    'manual activation retains baseline until explicitly activated',
    () async {
      final client = LocalisyncClient(
        config: config(activation: ActivationPolicy.manual),
        transport: FixtureTransport(),
        cache: MemoryDeliveryCache(),
      );
      expect((await client.ready).outcome, UpdateOutcome.pending);
      expect(client.translate('plain'), 'Bundled text');
      expect(client.hasPending, true);
      final before = client.status.contentVersion;
      await Future.wait([client.activatePending(), client.activatePending()]);
      expect(client.status.contentVersion, before + 1);
      expect(client.translate('plain'), 'Published text');
      await client.dispose();
    },
  );
  test('manual update policy starts without network', () async {
    final transport = FixtureTransport(),
        client = LocalisyncClient(
          config: config(update: UpdatePolicy.manual),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await client.ready;
    expect(transport.requests, 0);
    await client.refresh();
    expect(client.translate('plain'), 'Published text');
    await client.dispose();
  });
  test(
    'offline restart revalidates cache while baseline remains immediately available',
    () async {
      final cache = MemoryDeliveryCache(),
          first = LocalisyncClient(
            config: config(),
            transport: FixtureTransport(),
            cache: cache,
          );
      await first.ready;
      await first.dispose();
      final next = LocalisyncClient(
        config: config(),
        transport: FixtureTransport()..offline = true,
        cache: cache,
      );
      expect(next.translate('plain'), 'Bundled text');
      expect((await next.ready).outcome, UpdateOutcome.failed);
      expect(next.translate('plain'), 'Published text');
      await next.dispose();
    },
  );
  test('corrupt downloads and failures preserve usable content', () async {
    final transport = FixtureTransport(),
        client = LocalisyncClient(
          config: config(),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await client.ready;
    transport.offline = true;
    expect((await client.refresh()).outcome, UpdateOutcome.failed);
    expect(client.translate('plain'), 'Published text');
    await client.dispose();
    final broken = LocalisyncClient(
      config: config(),
      transport: FixtureTransport()..corrupt = true,
      cache: MemoryDeliveryCache(),
    );
    expect((await broken.ready).outcome, UpdateOutcome.failed);
    expect(broken.translate('plain'), 'Bundled text');
    await broken.dispose();
  });
  test('secondary node supplies the same immutable release', () async {
    final transport = FixtureTransport()..primaryOffline = true,
        client = LocalisyncClient(
          config: config(),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    expect((await client.ready).outcome, UpdateOutcome.updated);
    expect(transport.paths.any((p) => p.contains('secondary.invalid')), true);
    await client.dispose();
  });
  test(
    'monotonic revision permits rollback and rejects conflicting or stale catalogs',
    () async {
      final transport = FixtureTransport(),
          client = LocalisyncClient(
            config: config(),
            transport: transport,
            cache: MemoryDeliveryCache(),
          );
      await client.ready;
      transport.catalog = field('conflictJws');
      expect((await client.refresh()).failure?.code, FailureCode.staleRevision);
      transport.catalog = field('rollbackJws');
      expect((await client.refresh()).outcome, UpdateOutcome.unchanged);
      expect(client.status.revision, 3);
      transport.catalog = field('catalogJws');
      expect((await client.refresh()).failure?.code, FailureCode.staleRevision);
      expect(client.translate('plain'), 'Published text');
      await client.dispose();
    },
  );
  test('304 reuses only verified catalog and unchanged artifacts', () async {
    final transport = FixtureTransport(),
        client = LocalisyncClient(
          config: config(),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await client.ready;
    final before = transport.requests;
    transport.notModified = true;
    expect((await client.refresh()).outcome, UpdateOutcome.unchanged);
    expect(transport.requests, before + 1);
    await client.dispose();
  });
  test('locale switch does not check for new publications', () async {
    final transport = FixtureTransport(),
        client = LocalisyncClient(
          config: config(locale: 'en'),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await client.ready;
    final before = transport.requests;
    expect((await client.setLocale('tr')).outcome, UpdateOutcome.updated);
    expect(client.locale, 'tr');
    expect(transport.requests, before + 1);
    expect(
      client.translate('greeting', arguments: {'name': 'Ada'}),
      'Merhaba Ada',
    );
    expect((await client.setLocale('fr')).failure?.code, FailureCode.locale);
    expect(client.locale, 'tr');
    await client.dispose();
  });
  test(
    'storage degradation is reported without blocking verified memory updates',
    () async {
      final client = LocalisyncClient(
        config: config(),
        transport: FixtureTransport(),
        cache: FailingCache(),
      );
      final result = await client.ready;
      expect(result.outcome, UpdateOutcome.updated);
      expect(result.persisted, false);
      expect(client.translate('plain'), 'Published text');
      await client.dispose();
    },
  );
  test('no compatible publication selects bundled content', () async {
    final transport = FixtureTransport(),
        client = LocalisyncClient(
          config: config(),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    await client.ready;
    transport.catalog = field('emptyJws');
    expect((await client.refresh()).outcome, UpdateOutcome.bundled);
    expect(client.translate('plain'), 'Bundled text');
    await client.dispose();
  });
  test('late timeout responses cannot activate', () async {
    final transport = FixtureTransport()
          ..delay = const Duration(milliseconds: 40),
        client = LocalisyncClient(
          config: config(
            timeout: const Duration(milliseconds: 5),
            total: const Duration(milliseconds: 10),
          ),
          transport: transport,
          cache: MemoryDeliveryCache(),
        );
    expect((await client.ready).outcome, UpdateOutcome.failed);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(client.translate('plain'), 'Bundled text');
    await client.dispose();
  });
  test(
    'ICU handles nested select, offset, exact matches and apostrophe escaping',
    () {
      final compiled = CompiledMessage(
        entry(
          'message',
          "{who, select, me {{n, plural, offset:1 =0 {Nobody} one {'{'One'}' and #} other {# others}}} other {Unknown}}",
          parameters: {'who': ParameterType.text, 'n': ParameterType.number},
        ),
        'en',
      );
      expect(compiled.format({'who': 'me', 'n': 2}), '{One} and 1');
      expect(compiled.format({'who': 'me', 'n': 4}), '3 others');
      expect(
        () => compiled.format({'who': 'me', 'n': double.nan}),
        throwsA(isA<LocalisyncException>()),
      );
      expect(
        () => CompiledMessage(
          entry('bad', '{x, number}', parameters: {'x': ParameterType.number}),
          'en',
        ),
        throwsA(isA<LocalisyncException>()),
      );
    },
  );
  test('Arabic and Russian plural categories use CLDR rules', () {
    const pattern =
        '{n, plural, zero {zero} one {one} two {two} few {few} many {many} other {other}}';
    final ar = CompiledMessage(
      entry('plural', pattern, parameters: {'n': ParameterType.number}),
      'ar',
    );
    expect([0, 1, 2, 3, 11, 100].map((n) => ar.format({'n': n})), [
      'zero',
      'one',
      'two',
      'few',
      'many',
      'other',
    ]);
    final ru = CompiledMessage(
      entry('plural', pattern, parameters: {'n': ParameterType.number}),
      'ru',
    );
    expect(ru.format({'n': 1.5}), 'other');
    expect(ru.format({'n': 21}), 'one');
  });
}
