@TestOn('vm')
library;

import 'dart:convert';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/platform/preparer_io.dart';
import 'package:test/test.dart';
import 'support/delivery_fixture.dart';

void main() {
  const preparer = PlatformContentPreparer();
  final fixture = jsonDecode(deliveryFixture) as Map<String, Object?>;
  late ReleaseManifest manifest;
  late Map<String, LocaleFile> files;
  setUp(() async {
    manifest = ReleaseManifest.fromJson(
      await const CooperativeVerification().signed(
        fixture['manifestJws']! as String,
        {'test-1': fixture['publicKey']! as String},
        DeliveryLimits.bytes,
      ),
    );
    files = {};
    for (final source in (fixture['files']! as Map<String, Object?>).values) {
      final file = LocaleFile.fromJson(jsonDecode(source! as String));
      files[file.locale] = file;
    }
  });
  LocaleFile replace(LocaleFile file, List<TranslationEntry> entries) =>
      LocaleFile.fromJson({
        'protocol': 1,
        'releaseId': file.releaseId,
        'locale': file.locale,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      });
  test(
    'locale partitions preserve ICU, Missing and explicit fallback',
    () async {
      final expected = await prepareBundle(manifest, files);
      final actual = await preparer.prepare(manifest, files, {});
      expect(actual.fallbacks, expected.fallbacks);
      for (final locale in files.keys) {
        for (final entry in files[locale]!.entries.values) {
          final arguments = <String, Object>{
            for (final parameter in entry.parameters.entries)
              parameter.key: parameter.value == ParameterType.number
                  ? 22
                  : 'Ada',
          };
          final target = actual.find(locale, entry.key);
          final reference = expected.find(locale, entry.key);
          expect(target?.$2, reference?.$2);
          expect(target?.$1.format(arguments), reference?.$1.format(arguments));
        }
      }
    },
  );
  test(
    'equal-sized but different locale inventories reject the entire bundle',
    () async {
      final target = files.values.last;
      final entries = target.entries.values.toList();
      final original = entries.first;
      entries[0] = TranslationEntry(
        key: 'different_key',
        format: original.format,
        parameters: original.parameters,
        value: original.value,
      );
      files[target.locale] = replace(target, entries);
      await expectLater(
        preparer.prepare(manifest, files, {}),
        throwsA(
          isA<LocalisyncException>().having(
            (e) => e.code,
            'code',
            FailureCode.protocol,
          ),
        ),
      );
    },
  );
  test('a later locale cannot change an earlier ICU contract', () async {
    final target = files.values.last;
    final entries = target.entries.values.toList();
    final index = entries.indexWhere(
      (entry) => entry.format == MessageFormat.icu,
    );
    entries[index] = TranslationEntry(
      key: entries[index].key,
      format: MessageFormat.plain,
      parameters: const {},
      value: 'Different contract',
    );
    files[target.locale] = replace(target, entries);
    await expectLater(
      preparer.prepare(manifest, files, {}),
      throwsA(
        isA<LocalisyncException>().having(
          (e) => e.code,
          'code',
          FailureCode.incompatible,
        ),
      ),
    );
  });
  test(
    'application contracts remain authoritative for the first locale',
    () async {
      final first = files.values.first.entries.values.first;
      await expectLater(
        preparer.prepare(manifest, files, {
          first.key: TranslationEntry(
            key: first.key,
            format: MessageFormat.icu,
            parameters: const {'required': ParameterType.text},
            value: '{required}',
          ),
        }),
        throwsA(
          isA<LocalisyncException>().having(
            (e) => e.code,
            'code',
            FailureCode.incompatible,
          ),
        ),
      );
    },
  );
}
