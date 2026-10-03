@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/platform/cache_io.dart';
import 'package:test/test.dart';
import 'support/delivery_fixture.dart';

void main() {
  late Directory directory;
  late FileDeliveryCache cache;
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
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('localisync-cache-');
    cache = FileDeliveryCache(directory: () async => directory);
  });
  tearDown(() async {
    await cache.close();
    await directory.delete(recursive: true);
  });
  Future<bool> write(
    FileDeliveryCache target,
    int revision, {
    int max = 1024 * 1024,
    Cancellation? cancellation,
  }) => target.write(
    'scope',
    state,
    revision: revision,
    catalogDigest: 'digest-$revision',
    maxBytes: max,
    cancellation: cancellation,
  );
  test(
    'background isolates cannot bypass process-wide storage coordination',
    () async {
      final result = await Isolate.run(() {
        try {
          FileDeliveryCache();
          return false;
        } on LocalisyncException catch (e) {
          return e.code == FailureCode.configuration;
        }
      });
      expect(result, isTrue);
    },
  );
  test('restart, redundant metadata recovery and scope separation', () async {
    expect(await write(cache, 1), isTrue);
    await cache.close();
    cache = FileDeliveryCache(directory: () async => directory);
    expect((await cache.read('scope'))?.active?.files, generation.files);
    expect(await cache.read('another'), isNull);
    final records = await directory
        .list(recursive: true)
        .where((e) => e.path.endsWith('state-0.json'))
        .toList();
    await File(records.single.path).writeAsString('interrupted write');
    expect((await cache.read('scope'))?.active?.files, generation.files);
  });
  test('concurrent clients cannot regress the durable catalog', () async {
    final second = FileDeliveryCache(directory: () async => directory);
    await Future.wait([write(cache, 1), write(second, 3)]);
    expect(await write(cache, 2), isFalse);
    expect(await write(second, 3), isTrue);
    await second.close();
  });
  test('blob workers repair corruption and reject mismatched input', () async {
    await write(cache, 1);
    final blob = await directory
        .list(recursive: true)
        .where((entry) => entry.path.endsWith('.blob'))
        .first;
    final file = File(blob.path);
    final original = await file.readAsString();
    await file.writeAsBytes(List.filled(await file.length(), 0));
    expect(await write(cache, 2), isTrue);
    expect(await file.readAsString(), original);
    final invalid = CacheState(
      catalog: generation.catalog,
      active: CachedGeneration(
        catalog: generation.catalog,
        manifest: generation.manifest,
        locale: generation.locale,
        files: {'0' * 64: 'Content with a different digest'},
      ),
    );
    await expectLater(
      cache.write(
        'scope',
        invalid,
        revision: 3,
        catalogDigest: 'digest-3',
        maxBytes: 1024 * 1024,
      ),
      throwsA(
        isA<LocalisyncException>().having(
          (error) => error.code,
          'code',
          FailureCode.integrity,
        ),
      ),
    );
    expect((await cache.read('scope'))?.active?.files, generation.files);
    expect(await write(cache, 2), isTrue);
  });
  test(
    'large Unicode blobs use byte budgets and preserve a failed commit',
    () async {
      await write(cache, 1);
      final source = '日本語🌍' * 20000;
      final digest = await sha256Hex(utf8.encode(source));
      final large = CacheState(
        catalog: generation.catalog,
        active: CachedGeneration(
          catalog: generation.catalog,
          manifest: generation.manifest,
          locale: generation.locale,
          files: {digest: source},
        ),
        previous: generation,
      );
      Future<bool> commit(int budget) => cache.write(
        'scope',
        large,
        revision: 2,
        catalogDigest: 'digest-2',
        maxBytes: budget,
      );
      await expectLater(
        commit(source.length),
        throwsA(isA<LocalisyncException>()),
      );
      expect((await cache.read('scope'))?.active?.files, generation.files);
      expect(await commit(1024 * 1024), true);
      final restored = await cache.read('scope');
      expect(restored?.active?.files, {digest: source});
      expect(restored?.previous?.files, generation.files);
    },
  );
  test(
    'unknown cache schema is preserved instead of resetting revision protection',
    () async {
      await write(cache, 1);
      final file = File(
        (await directory
                .list(recursive: true)
                .where((e) => e.path.endsWith('state-0.json'))
                .first)
            .path,
      );
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final record =
          jsonDecode(envelope['payload']! as String) as Map<String, Object?>;
      record['version'] = 99;
      final payload = jsonEncode(record);
      final encoded = jsonEncode({
        'payload': payload,
        'digest': await sha256Hex(utf8.encode(payload)),
      });
      await file.writeAsString(encoded);
      await expectLater(
        cache.read('scope'),
        throwsA(isA<LocalisyncException>()),
      );
      await expectLater(write(cache, 2), throwsA(isA<LocalisyncException>()));
      expect(await file.readAsString(), encoded);
    },
  );
  test(
    'interrupted unreferenced staging files are reclaimed before budgeting',
    () async {
      await write(cache, 1);
      final folder =
          (await directory
                  .list(recursive: true)
                  .where((e) => e.path.endsWith('lock'))
                  .first)
              .parent;
      final abandoned = File('${folder.path}/${'0' * 64}.blob');
      await abandoned.writeAsBytes(List.filled(2 * 1024 * 1024, 1));
      final temporary = File('${folder.path}/interrupted.tmp');
      await temporary.writeAsString('incomplete');
      expect(await write(cache, 2), true);
      expect(await abandoned.exists(), false);
      expect(await temporary.exists(), false);
      expect((await cache.read('scope'))?.active?.files, generation.files);
    },
  );
  test('budget and cancellation preserve previous content', () async {
    await write(cache, 1);
    await expectLater(
      write(cache, 2, max: 1),
      throwsA(isA<LocalisyncException>()),
    );
    final cancelled = Cancellation()..cancel();
    await expectLater(
      write(cache, 2, cancellation: cancelled),
      throwsA(isA<LocalisyncException>()),
    );
    expect((await cache.read('scope'))?.active?.catalog, generation.catalog);
    expect(await write(cache, 1), isTrue);
  });
  test(
    'missing blob recovers previous generation without partial active content',
    () async {
      await write(cache, 1);
      final blobs = await directory
          .list(recursive: true)
          .where((e) => e.path.endsWith('.blob'))
          .toList();
      await blobs.first.delete();
      expect((await cache.read('scope'))?.active, isNull);
      expect((await cache.read('scope'))?.catalog, generation.catalog);
    },
  );
}
