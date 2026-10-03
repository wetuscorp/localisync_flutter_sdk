import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:localisync_sdk/core.dart';
import 'package:yaml/yaml.dart';

final class GenerationInput {
  GenerationInput(this.fallbacks, this.entries, this.names, this.localOnly);
  final Map<String, String?> fallbacks;
  final Map<String, List<TranslationEntry>> entries;
  final Map<String, String> names;
  final List<String> localOnly;
  Iterable<TranslationEntry> get definitions => entries.values
      .expand((v) => v)
      .fold<Map<String, TranslationEntry>>(
        {},
        (all, e) => all..putIfAbsent(e.key, () => e),
      )
      .values;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  final result = <String, Object?>{};
  for (final key in value.keys) {
    if (key is! String) throw FormatException('$field requires string keys.');
    result[key] = value[key];
  }
  return result;
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty)
    throw FormatException('$field must be a nonempty string.');
  return value;
}

String dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
const _reserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
  'client',
  'locale',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};
String dartName(String key, Map<String, String> names) {
  final name = names[key] ?? key;
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name) ||
      _reserved.contains(name))
    throw FormatException(
      'Key "$key" needs an explicit, valid Dart name in names.',
    );
  return name;
}

Future<GenerationInput> readArbInput(File configFile) async {
  final config = _map(
    loadYaml(await configFile.readAsString()),
    'configuration',
  );
  final input = _map(config['arb'], 'arb'),
      fallbackInput = _map(config['fallbacks'], 'fallbacks');
  final useEscaping = config['useEscaping'] ?? false;
  if (useEscaping is! bool)
    throw const FormatException('useEscaping must be a boolean.');
  final fallbacks = fallbackInput.map(
    (key, value) =>
        MapEntry(key, value == null ? null : _string(value, 'fallback')),
  );
  validateFallbacks(fallbacks);
  final names = config['names'] == null
      ? <String, String>{}
      : _map(
          config['names'],
          'names',
        ).map((k, v) => MapEntry(k, _string(v, 'name')));
  final entries = <String, List<TranslationEntry>>{}, localOnly = <String>{};
  final contracts = <String, Map<String, ParameterType>>{};
  final sources = <String, Map<String, Object?>>{};
  for (final item in input.entries) {
    if (!fallbacks.containsKey(item.key))
      throw FormatException('Declare an explicit fallback for ${item.key}.');
    final file = File.fromUri(
      configFile.uri.resolve(_string(item.value, 'ARB path')),
    );
    if (await file.length() > DeliveryLimits.bytes)
      throw const FormatException('ARB file exceeds 100 MiB.');
    final values = _map(await decodeDocument(await file.readAsString()), 'ARB');
    if (values['@@locale'] != null &&
        values['@@locale'] != item.key &&
        values['@@locale'] != item.key.replaceAll('-', '_'))
      throw FormatException(
        'ARB locale differs from configuration: ${item.key}.',
      );
    sources[item.key] = values;
    for (final key in values.keys.where((key) => !key.startsWith('@'))) {
      final metadata = values['@$key'] == null
          ? <String, Object?>{}
          : _map(values['@$key'], 'ARB metadata');
      final placeholders = metadata['placeholders'] == null
          ? <String, Object?>{}
          : _map(metadata['placeholders'], 'placeholders');
      final parameters = <String, ParameterType>{};
      for (final p in placeholders.entries) {
        final data = _map(p.value, 'placeholder'),
            type = data['type'] ?? 'String';
        if (data['format'] != null ||
            !['String', 'num', 'int', 'double'].contains(type)) {
          localOnly.add(key);
          continue;
        }
        parameters[p.key] = type == 'String'
            ? ParameterType.text
            : ParameterType.number;
      }
      if (parameters.isNotEmpty) {
        final existing = contracts[key];
        if (existing != null &&
            (parameters.length != existing.length ||
                parameters.entries.any((p) => existing[p.key] != p.value)))
          throw FormatException(
            'ARB parameter contract differs between locales: $key.',
          );
        contracts[key] = parameters;
      }
    }
  }
  if (fallbacks.keys.any((locale) => !sources.containsKey(locale)))
    throw const FormatException('Every fallback locale needs an ARB file.');
  final assigned = <String, String>{};
  for (final source in sources.entries) {
    final values = <TranslationEntry>[];
    for (final item in source.value.entries.where(
      (e) => !e.key.startsWith('@'),
    )) {
      if (localOnly.contains(item.key)) continue;
      if (item.value != null && item.value is! String)
        throw FormatException('ARB values must be strings: ${item.key}.');
      var value = item.value as String?;
      final parameters = contracts[item.key] ?? {};
      final format = parameters.isEmpty
          ? MessageFormat.plain
          : MessageFormat.icu;
      // ARB always uses message syntax, including messages without placeholders.
      // Match gen_l10n's explicit use-escaping option before storing the baseline.
      if (value != null && value.trim().isNotEmpty) {
        final message = useEscaping ? value : value.replaceAll("'", "''");
        final compiled = CompiledMessage(
          TranslationEntry(
            key: item.key,
            format: MessageFormat.icu,
            parameters: parameters,
            value: message,
          ),
          source.key,
        );
        value = parameters.isEmpty ? compiled.format(const {}) : message;
      }
      final entry = TranslationEntry(
        key: item.key,
        format: format,
        parameters: parameters,
        value: value == null || value.trim().isEmpty ? null : value,
      );
      if (entry.value != null) CompiledMessage(entry, source.key);
      final name = dartName(item.key, names), old = assigned[name];
      if (old != null && old != item.key)
        throw FormatException('Two keys map to the same Dart name: $name.');
      assigned[name] = item.key;
      values.add(entry);
    }
    entries[source.key] = values;
  }
  return GenerationInput(fallbacks, entries, names, localOnly.toList()..sort());
}

Future<GenerationInput> readReleaseInput(
  File packageFile,
  Map<String, String> keys, {
  Map<String, String> names = const {},
}) async {
  if (await packageFile.length() > DeliveryLimits.bytes * 2)
    throw const FormatException('Release package exceeds its limit.');
  final cached = CachedGeneration.fromJson(
    await decodeDocument(
      await packageFile.readAsString(),
      maxBytes: DeliveryLimits.bytes * 2,
    ),
  );
  final verifier = SignatureVerifier(keys);
  final catalog = Catalog.fromJson(
    await verifier.verify(
      cached.catalog,
      maxPayloadBytes: DeliveryLimits.catalog,
    ),
  );
  final manifest = ReleaseManifest.fromJson(
    await verifier.verify(
      cached.manifest,
      maxPayloadBytes: DeliveryLimits.bytes,
    ),
  );
  final digest = await sha256Hex(utf8.encode(cached.manifest));
  if (manifest.projectId != catalog.projectId ||
      !catalog.publications.any(
        (p) =>
            p.releaseId == manifest.releaseId &&
            p.manifestDigest == digest &&
            p.compatibility.sameAs(manifest.compatibility),
      )) {
    throw const FormatException(
      'Release package does not belong to the signed catalog.',
    );
  }
  final files = <String, LocaleFile>{};
  final entries = <String, List<TranslationEntry>>{},
      fallbacks = <String, String?>{};
  final descriptors = manifest.files.values
      .where((d) => cached.files.containsKey(d.digest))
      .toList();
  final knownDigests = descriptors.map((d) => d.digest).toSet();
  if (!manifest.requestedLocales.contains(cached.locale) ||
      descriptors.isEmpty ||
      cached.files.keys.any((digest) => !knownDigests.contains(digest)))
    throw const FormatException(
      'Release baseline contains unknown or missing locale artifacts.',
    );
  final available = descriptors.map((d) => d.locale).toSet();
  if (!available.contains(cached.locale) ||
      available.any(
        (locale) =>
            manifest.languages[locale] != null &&
            !available.contains(manifest.languages[locale]),
      ))
    throw const FormatException(
      'Release baseline must contain every explicit fallback dependency.',
    );
  for (final descriptor in descriptors) {
    final source = cached.files[descriptor.digest];
    if (source == null) continue;
    final bytes = utf8.encode(source);
    if (bytes.length != descriptor.bytes ||
        await sha256Hex(bytes) != descriptor.digest)
      throw const FormatException('Invalid release artifact integrity.');
    final file = LocaleFile.fromJson(await decodeDocument(source));
    if (file.locale != descriptor.locale ||
        file.releaseId != manifest.releaseId ||
        file.entries.length != manifest.keyCount)
      throw const FormatException('Incorrect artifact inventory.');
    files[file.locale] = file;
    entries[file.locale] = file.entries.values.toList();
    fallbacks[file.locale] = manifest.languages[file.locale];
  }
  validateFallbacks(fallbacks);
  await prepareBundle(manifest, files);
  final seen = <String, String>{};
  for (final item in entries.entries) {
    for (final e in item.value) {
      if (e.value != null) CompiledMessage(e, item.key);
      final name = dartName(e.key, names);
      if (seen[name] != null && seen[name] != e.key)
        throw FormatException('Dart name collision: $name.');
      seen[name] = e.key;
    }
  }
  return GenerationInput(fallbacks, entries, names, []);
}

String _entryCode(TranslationEntry entry) =>
    'TranslationEntry(key: ${dartString(entry.key)}, format: MessageFormat.${entry.format.name}, parameters: {${entry.parameters.entries.map((p) => '${dartString(p.key)}: ParameterType.${p.value.name}').join(', ')}}, value: ${entry.value == null ? 'null' : dartString(entry.value!)})';
String generateTyped(
  GenerationInput input, {
  String className = 'LocalisyncMessages',
}) {
  dartName(className, {});
  final out = StringBuffer(
    "// Generated by localisync_generator. Edit the input configuration instead.\nimport 'package:localisync_sdk/localisync_sdk.dart';\n\n",
  );
  out.writeln(
    'TranslationBundle createLocalisyncBundle() => TranslationBundle(fallbacks: {${input.fallbacks.entries.map((e) => '${dartString(e.key)}: ${e.value == null ? 'null' : dartString(e.value!)}').join(',')}}, entries: {',
  );
  for (final locale in input.entries.entries) {
    out.writeln(
      '${dartString(locale.key)}: [${locale.value.map(_entryCode).join(',')}],',
    );
  }
  out.writeln('});');
  out.writeln(
    'Map<String, TranslationEntry> localisyncContracts() => {${input.definitions.map((e) => '${dartString(e.key)}: ${_entryCode(TranslationEntry(key: e.key, format: e.format, parameters: e.parameters, value: null))}').join(',')}};',
  );
  out.writeln(
    'class $className {\n  const $className(this.client);\n  final LocalisyncClient client;',
  );
  for (final entry in input.definitions) {
    final name = dartName(entry.key, input.names),
        params = entry.parameters.entries.toList();
    for (final p in params) {
      dartName(p.key, {});
    }
    final args = params
        .map(
          (p) =>
              'required ${p.value == ParameterType.text ? 'String' : 'num'} ${p.key}',
        )
        .join(', ');
    out.writeln(
      '  String ${params.isEmpty ? 'get $name' : '$name({$args})'} => client.translate(${dartString(entry.key)}, arguments: {${params.map((p) => '${dartString(p.key)}: ${p.key}').join(', ')}});',
    );
  }
  out.writeln('}');
  return out.toString();
}

/// Reads only the generated public class. No imports from Flutter tool implementation.
String generateAdapter(
  GenerationInput input,
  String source, {
  required String importPath,
  String className = 'AppLocalizations',
}) {
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  if (parsed.errors.isNotEmpty)
    throw const FormatException(
      'Generated localization source has syntax errors.',
    );
  final classes = parsed.unit.declarations
      .whereType<ClassDeclaration>()
      .where((c) => c.namePart.typeName.lexeme == className)
      .toList();
  if (classes.length != 1 ||
      classes.single.finalKeyword != null ||
      classes.single.sealedKeyword != null)
    throw const FormatException(
      'Expected one extensible generated localization class.',
    );
  final definitions = {
    for (final e in input.definitions) dartName(e.key, input.names): e,
  };
  final out = StringBuffer(
    "// Generated by localisync_generator. Edit the input configuration instead.\nimport 'package:flutter/widgets.dart';\nimport 'package:localisync_sdk/localisync_sdk.dart';\nimport ${dartString(importPath)};\n\n",
  );
  out.writeln(
    'class Localisync${className}Delegate extends LocalizationsDelegate<$className> {\n  Localisync${className}Delegate(this.client) : revision = client.status.contentVersion;\n  final LocalisyncClient client;\n  final int revision;\n  @override bool isSupported(Locale locale) => $className.delegate.isSupported(locale);\n  @override Future<$className> load(Locale locale) async => _Localisync$className(await $className.delegate.load(locale), client, locale.toLanguageTag());\n  @override bool shouldReload(Localisync${className}Delegate old) => client != old.client || revision != old.revision;\n}',
  );
  out.writeln(
    'class _Localisync$className extends $className {\n  _Localisync$className(this.bundled, this.client, this.tag) : super(bundled.localeName);\n  final $className bundled;\n  final LocalisyncClient client;\n  final String tag;',
  );
  for (final method
      in classes.single.body.members.whereType<MethodDeclaration>().where(
        (m) => m.isAbstract && !m.isStatic,
      )) {
    if (method.returnType?.toSource() != 'String' || method.isSetter)
      throw const FormatException('Expected generated String accessors.');
    final name = method.name.lexeme,
        params = method.parameters?.parameters.toList() ?? <FormalParameter>[];
    final names = <String>[], types = <String, String>{};
    for (final parameter in params) {
      final normal = parameter is DefaultFormalParameter
          ? parameter.parameter
          : parameter;
      if (normal is! SimpleFormalParameter || parameter.name == null)
        throw const FormatException(
          'Unsupported localization method parameter.',
        );
      names.add(parameter.name!.lexeme);
      types[parameter.name!.lexeme] = normal.type?.toSource() ?? 'Object';
    }
    final fallback =
        'bundled.$name${method.isGetter ? '' : '(${params.map((p) => p.isNamed ? '${p.name!.lexeme}: ${p.name!.lexeme}' : p.name!.lexeme).join(', ')})'}';
    final definition = definitions[name];
    final signature =
        'String ${method.isGetter ? 'get $name' : '$name${method.parameters!.toSource()}'}';
    if (definition == null) {
      out.writeln('  @override $signature => $fallback;');
      continue;
    }
    if (definition.parameters.length != params.length ||
        definition.parameters.entries.any(
          (p) =>
              !names.contains(p.key) ||
              (p.value == ParameterType.text
                  ? !['String', 'Object'].contains(types[p.key])
                  : !['int', 'double', 'num', 'Object'].contains(types[p.key])),
        ))
      throw FormatException(
        'Localization signature differs from the translation contract: $name.',
      );
    final args = names.map((n) => '${dartString(n)}: $n').join(', ');
    out.writeln(
      '  @override $signature {\n    final result = client.resolve(${dartString(definition.key)}, locale: tag, arguments: {$args});\n    return result.source == ContentSource.remote && result.failure == null ? result.text : $fallback;\n  }',
    );
  }
  out.writeln('}');
  return out.toString();
}
