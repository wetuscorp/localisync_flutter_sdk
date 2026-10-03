@TestOn('browser')
library;

import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/platform/cache_web.dart';
import 'package:test/test.dart';
import 'support/delivery_fixture.dart';

void main() {
  final fixture = jsonDecode(deliveryFixture) as Map<String, Object?>;
  final generation = CachedGeneration(
    catalog: fixture['catalogJws']! as String,
    manifest: fixture['manifestJws']! as String,
    locale: 'tr',
    files: (fixture['files']! as Map<String, Object?>).map(
      (k, v) => MapEntry(k, v! as String),
    ),
  );
  final state = CacheState(catalog: generation.catalog, active: generation);
  late String database;
  late IndexedDbDeliveryCache first, second;
  setUp(() {
    database = 'localisync-test-${DateTime.now().microsecondsSinceEpoch}';
    first = IndexedDbDeliveryCache(databaseName: database);
    second = IndexedDbDeliveryCache(databaseName: database);
  });
  tearDown(() async {
    await first.close();
    await second.close();
    web.window.indexedDB.deleteDatabase(database);
  });
  Future<bool> write(
    IndexedDbDeliveryCache cache,
    int revision, {
    int max = 1024 * 1024,
  }) => cache.write(
    'scope',
    state,
    revision: revision,
    catalogDigest: 'digest-$revision',
    maxBytes: max,
  );
  test(
    'IndexedDB survives client recreation and keeps scope separate',
    () async {
      expect(await write(first, 1), isTrue);
      await first.close();
      expect((await second.read('scope'))?.active?.files, generation.files);
      expect(await second.read('unrelated'), isNull);
    },
  );
  test(
    'concurrent IndexedDB connections preserve the newest revision',
    () async {
      await Future.wait([write(first, 1), write(second, 3)]);
      expect(await write(first, 2), isFalse);
      expect(await write(second, 3), isTrue);
      expect(
        await second.write(
          'scope',
          state,
          revision: 3,
          catalogDigest: 'conflict',
          maxBytes: 1024 * 1024,
        ),
        isFalse,
      );
    },
  );
  test('quota failure leaves the committed generation intact', () async {
    await write(first, 1);
    await expectLater(
      write(second, 2, max: 1),
      throwsA(isA<LocalisyncException>()),
    );
    expect((await first.read('scope'))?.active?.files, generation.files);
    expect(await write(second, 1), isTrue);
  });
}
