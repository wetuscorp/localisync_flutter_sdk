import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:localisync_generator/localisync_generator.dart';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run localisync_generator:generate localisync.yaml',
    );
    exitCode = 64;
    return;
  }
  try {
    final file = File(args.single).absolute;
    final config = loadYaml(await file.readAsString());
    if (config is! YamlMap)
      throw const FormatException('Expected a configuration map.');
    const fields = {
      'output',
      'arb',
      'fallbacks',
      'names',
      'release',
      'trustedKeys',
      'adapter',
      'useEscaping',
    };
    if (config.keys.any((key) => !fields.contains(key)))
      throw const FormatException('Unknown configuration field.');
    if (config.containsKey('arb') == config.containsKey('release'))
      throw const FormatException(
        'Configure exactly one input: arb or release.',
      );
    if (config.containsKey('release') && config['release'] is! String)
      throw const FormatException('release must be a file path.');
    if (config.containsKey('adapter') && config['adapter'] is! YamlMap)
      throw const FormatException('adapter must be an object.');
    if (config.containsKey('names') && config['names'] is! YamlMap)
      throw const FormatException('names must be an object.');
    final inputs = <File>[file];
    if (config['arb'] case final YamlMap arb) {
      for (final value in arb.values) {
        if (value is! String)
          throw const FormatException('ARB input must be a file path.');
        inputs.add(File.fromUri(file.uri.resolve(value)));
      }
    }
    final output = config['output'];
    if (output is! String || output.isEmpty)
      throw const FormatException('Configure the generated Dart output path.');
    late final GenerationInput input;
    if (config['release'] case final String release) {
      inputs.add(File.fromUri(file.uri.resolve(release)));
      final trust = config['trustedKeys'];
      if (trust is! YamlMap)
        throw const FormatException('Release input requires trustedKeys.');
      final keys = <String, String>{};
      for (final key in trust.keys) {
        if (key is! String || trust[key] is! String)
          throw const FormatException('Invalid trust anchor.');
        keys[key] = trust[key] as String;
      }
      final names = <String, String>{};
      if (config['names'] case final YamlMap mappings) {
        for (final key in mappings.keys) {
          if (key is! String || mappings[key] is! String)
            throw const FormatException('Invalid name mapping.');
          names[key] = mappings[key] as String;
        }
      }
      input = await readReleaseInput(
        File.fromUri(file.uri.resolve(release)),
        keys,
        names: names,
      );
    } else {
      input = await readArbInput(file);
    }
    final generated = <File, String>{
      File.fromUri(file.uri.resolve(output)): generateTyped(input),
    };
    if (config['adapter'] case final YamlMap adapter) {
      if (adapter.keys.any(
        (key) => !{'source', 'output', 'import'}.contains(key),
      ))
        throw const FormatException('Unknown adapter field.');
      final source = adapter['source'],
          destination = adapter['output'],
          import = adapter['import'];
      if (source is! String || destination is! String || import is! String) {
        throw const FormatException(
          'Adapter requires source, output and import paths.',
        );
      }
      inputs.add(File.fromUri(file.uri.resolve(source)));
      generated[File.fromUri(file.uri.resolve(destination))] = generateAdapter(
        input,
        await File.fromUri(file.uri.resolve(source)).readAsString(),
        importPath: import,
      );
    }
    final protectedPaths = <String>{};
    for (final input in inputs) {
      protectedPaths.add(await _canonical(input));
    }
    final outputs = <String>{};
    for (final destination in generated.keys) {
      final path = await _canonical(destination);
      if (!path.endsWith('.dart') ||
          protectedPaths.contains(path) ||
          !outputs.add(path))
        throw const FormatException(
          'Outputs must be distinct Dart files and cannot overwrite input files.',
        );
    }
    for (final text in generated.values) {
      if (parseString(
        content: text,
        throwIfDiagnostics: false,
      ).errors.isNotEmpty) {
        throw const FormatException('Generated code failed syntax validation.');
      }
    }
    for (final entry in generated.entries) {
      if (entry.key.absolute.path == file.path)
        throw const FormatException('Output cannot overwrite configuration.');
      await entry.key.parent.create(recursive: true);
      final temp = File('${entry.key.path}.tmp.$pid');
      try {
        await temp.writeAsString(entry.value, flush: true);
        final formatted = await Process.run(Platform.resolvedExecutable, [
          'format',
          temp.path,
        ]);
        if (formatted.exitCode != 0)
          throw const FormatException('Generated code could not be formatted.');
        await temp.rename(entry.key.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
    stdout.writeln(
      'Generated ${generated.length} Dart files from ${input.definitions.length} translation keys.',
    );
    if (input.localOnly.isNotEmpty)
      stdout.writeln('Bundled delegate only: ${input.localOnly.join(', ')}.');
  } on Object catch (error) {
    stderr.writeln(
      error is FormatException
          ? error.message
          : 'Generation failed. Check configuration, file access and signed input integrity.',
    );
    exitCode = 1;
  }
}

Future<String> _canonical(File file) async {
  if (await file.exists()) return file.resolveSymbolicLinks();
  var parent = file.absolute.parent;
  final segments = <String>[file.uri.pathSegments.last];
  while (!await parent.exists()) {
    segments.insert(
      0,
      parent.uri.pathSegments.where((part) => part.isNotEmpty).last,
    );
    parent = parent.parent;
  }
  return '${await parent.resolveSymbolicLinks()}${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}';
}
