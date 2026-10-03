import 'dart:convert';
import 'dart:io';
import 'package:localisync_sdk/core.dart';
import 'package:test/test.dart';

void main() {
  final source =
      jsonDecode(
            File(
              File('../../test/sdk-protocol/icu.json').existsSync()
                  ? '../../test/sdk-protocol/icu.json'
                  : '../../../../test/sdk-protocol/icu.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final valid = source['valid']! as List<Object?>;
  for (var index = 0; index < valid.length; index++) {
    final fixture = valid[index]! as Map<String, Object?>;
    test('server ICU conformance $index (${fixture['locale']})', () {
      final parameters = <String, ParameterType>{};
      for (final value in fixture['parameters']! as List<Object?>) {
        final parameter = value! as Map<String, Object?>;
        parameters[parameter['name']! as String] = ParameterType.values.byName(
          parameter['type']! as String,
        );
      }
      final entry = TranslationEntry(
        key: 'fixture',
        format: MessageFormat.icu,
        parameters: parameters,
        value: fixture['message']! as String,
      );
      final args = (fixture['args']! as Map<String, Object?>).map(
        (k, v) => MapEntry(k, v!),
      );
      expect(
        CompiledMessage(entry, fixture['locale']! as String).format(args),
        fixture['expected'],
      );
    });
  }
  for (final message in source['invalid']! as List<Object?>) {
    test('server rejected syntax: $message', () {
      expect(
        () => CompiledMessage(
          TranslationEntry(
            key: 'fixture',
            format: MessageFormat.icu,
            parameters: {'n': ParameterType.number},
            value: message! as String,
          ),
          'en',
        ),
        throwsA(isA<LocalisyncException>()),
      );
    });
  }
}
