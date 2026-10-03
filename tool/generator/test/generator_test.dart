import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_generator/localisync_generator.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('localisync-generator-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<File> configuration(
    Map<String, Object?> arb, {
    String extra = '',
  }) async {
    await File('${directory.path}/en.arb').writeAsString(jsonEncode(arb));
    final config = File('${directory.path}/localisync.yaml');
    await config.writeAsString(
      'arb:\n  en: en.arb\nfallbacks:\n  en: null\n$extra',
    );
    return config;
  }

  test(
    'typed generation escapes literals and keeps numeric/text contracts',
    () async {
      final input = await readArbInput(
        await configuration({
          'title': r'Price $5',
          'hello': 'Hello {name}: {count, plural, one {one} other {#}}',
          '@hello': {
            'placeholders': {
              'name': {'type': 'String'},
              'count': {'type': 'int'},
            },
          },
        }),
      );
      final source = generateTyped(input);
      expect(parseString(content: source).errors, isEmpty);
      expect(source, contains('required String name'));
      expect(source, contains('required num count'));
      expect(source, contains(r'Price \$5'));
    },
  );
  test('invalid names require mapping and collisions are rejected', () async {
    await expectLater(
      readArbInput(await configuration({'hello.world': 'Hello'})),
      throwsFormatException,
    );
    final input = await readArbInput(
      await configuration({
        'hello.world': 'Hello',
      }, extra: 'names:\n  hello.world: helloWorld\n'),
    );
    expect(generateTyped(input), contains('get helloWorld'));
    await expectLater(
      readArbInput(
        await configuration({
          'hello': 'One',
          'hi': 'Two',
        }, extra: 'names:\n  hi: hello\n'),
      ),
      throwsFormatException,
    );
  });
  test(
    'gen_l10n wrapper delegates unsupported formatting and preserves signatures',
    () async {
      final input = await readArbInput(
        await configuration({
          'hello': 'Hello {name}',
          '@hello': {
            'placeholders': {
              'name': {'type': 'String'},
            },
          },
          'date': '{date}',
          '@date': {
            'placeholders': {
              'date': {'type': 'DateTime', 'format': 'yMd'},
            },
          },
        }),
      );
      expect(input.localOnly, ['date']);
      const original = '''abstract class AppLocalizations {
      AppLocalizations(this.localeName); final String localeName;
      String hello(String name); String date(DateTime date);
    }''';
      final source = generateAdapter(
        input,
        original,
        importPath: 'app_localizations.dart',
      );
      expect(parseString(content: source).errors, isEmpty);
      expect(source, contains('String hello(String name)'));
      expect(
        source,
        contains('String date(DateTime date) => bundled.date(date)'),
      );
      expect(source, contains('revision != old.revision'));
      expect(
        () => generateAdapter(
          input,
          original.replaceAll('String name)', 'int name)'),
          importPath: 'app_localizations.dart',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'signed release input verifies exact manifest and artifact bytes',
    () async {
      final fixture =
          jsonDecode(
                await File(
                  File('../../test/sdk-protocol/delivery.json').existsSync()
                      ? '../../test/sdk-protocol/delivery.json'
                      : '../../../../test/sdk-protocol/delivery.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final package = File('${directory.path}/release.json');
      final generation = CachedGeneration(
        catalog: fixture['catalogJws']! as String,
        manifest: fixture['manifestJws']! as String,
        locale: 'tr',
        files: (fixture['files']! as Map<String, Object?>).map(
          (k, v) => MapEntry(k, v! as String),
        ),
      );
      await package.writeAsString(jsonEncode(generation.toJson()));
      final input = await readReleaseInput(package, {
        'test-1': fixture['publicKey']! as String,
      });
      expect(input.entries.keys, containsAll(['en', 'tr']));
      final english = generation.files.entries.singleWhere(
        (entry) =>
            (jsonDecode(entry.value) as Map<String, Object?>)['locale'] == 'en',
      );
      await package.writeAsString(
        jsonEncode(
          CachedGeneration(
            catalog: generation.catalog,
            manifest: generation.manifest,
            locale: 'en',
            files: {english.key: english.value},
          ).toJson(),
        ),
      );
      final subset = await readReleaseInput(package, {
        'test-1': fixture['publicKey']! as String,
      });
      expect(subset.fallbacks, {'en': null});
      expect(subset.entries.keys, ['en']);
      final corrupt = generation.toJson();
      corrupt['files'] = {
        for (final e in generation.files.entries) e.key: '${e.value}x',
      };
      await package.writeAsString(jsonEncode(corrupt));
      await expectLater(
        readReleaseInput(package, {'test-1': fixture['publicKey']! as String}),
        throwsFormatException,
      );
    },
  );
  test('ARB escaping is explicit even without arguments', () async {
    final escaped = await readArbInput(
      await configuration({
        'literal': "This '{is}' a ''quote''",
      }, extra: 'useEscaping: true\n'),
    );
    expect(escaped.entries['en']!.single.value, "This {is} a 'quote'");
    final normal = await readArbInput(
      await configuration({'literal': "It's fine"}),
    );
    expect(normal.entries['en']!.single.value, "It's fine");
    await expectLater(
      readArbInput(await configuration({'undeclared': '{name}'})),
      throwsA(isA<LocalisyncException>()),
    );
  });
  test(
    'CLI rejects ambiguous configuration and protected output paths before writing',
    () async {
      final config = await configuration({
        'title': 'Hello',
      }, extra: 'output: generated.dart\nrelease: data.json\n');
      final runner = File('bin/generate.dart').absolute.path;
      var result = await Process.run(Platform.resolvedExecutable, [
        runner,
        config.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('exactly one input'));
      const original =
          'abstract class AppLocalizations { AppLocalizations(String locale); String get title; }';
      final source = File('${directory.path}/original.dart');
      await source.writeAsString(original);
      await configuration(
        {'title': 'Hello'},
        extra:
            'output: original.dart\nadapter:\n  source: original.dart\n  output: adapter.dart\n  import: original.dart\n',
      );
      result = await Process.run(Platform.resolvedExecutable, [
        runner,
        config.path,
      ]);
      expect(result.exitCode, 1);
      expect(await source.readAsString(), original);
      expect(await File('${directory.path}/adapter.dart').exists(), false);
    },
  );
}
