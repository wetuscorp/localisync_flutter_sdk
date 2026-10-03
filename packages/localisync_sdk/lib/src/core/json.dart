import 'dart:convert';
import 'failure.dart';

/// Bounded JSON decoder that rejects duplicate object keys and yields on large input.
/// Unlike jsonDecode's reviver, duplicate names cannot disappear before validation.
Future<Object?> decodeDocument(
  String input, {
  int maxBytes = 100 * 1024 * 1024,
}) async {
  if (input.length > maxBytes || utf8.encode(input).length > maxBytes) {
    invalid('Document size limit exceeded.');
  }
  final reader = _JsonReader(input);
  final value = await reader.value(0);
  reader.space();
  if (reader.index != input.length) invalid('Unexpected JSON suffix.');
  return value;
}

final class _JsonReader {
  _JsonReader(this.source);
  final String source;
  int index = 0;
  int _operations = 0;
  void space() {
    while (index < source.length &&
        [9, 10, 13, 32].contains(source.codeUnitAt(index))) {
      index++;
    }
  }

  Future<Object?> value(int depth) async {
    if (depth > 64) invalid('JSON nesting limit exceeded.');
    if (++_operations % 256 == 0) await Future<void>.delayed(Duration.zero);
    space();
    if (index == source.length) invalid('Incomplete JSON document.');
    final char = source[index];
    if (char == '"') return string();
    if (char == '{') {
      index++;
      final result = <String, Object?>{};
      space();
      if (take('}')) return result;
      while (true) {
        space();
        if (index >= source.length || source[index] != '"')
          invalid('Expected an object key.');
        final key = await string();
        if (result.containsKey(key)) invalid('Duplicate JSON property.');
        space();
        if (!take(':')) invalid('Expected a JSON colon.');
        result[key] = await value(depth + 1);
        space();
        if (take('}')) return result;
        if (!take(',')) invalid('Expected a JSON separator.');
      }
    }
    if (char == '[') {
      index++;
      final result = <Object?>[];
      space();
      if (take(']')) return result;
      while (true) {
        result.add(await value(depth + 1));
        space();
        if (take(']')) return result;
        if (!take(',')) invalid('Expected a JSON separator.');
      }
    }
    for (final literal in ['true', 'false', 'null']) {
      if (source.startsWith(literal, index)) {
        index += literal.length;
        return literal == 'null' ? null : literal == 'true';
      }
    }
    final match = RegExp(
      r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
    ).matchAsPrefix(source, index);
    if (match == null) invalid('Invalid JSON value.');
    index = match.end;
    final n = num.tryParse(match.group(0)!);
    if (n == null || !n.isFinite) invalid('Invalid JSON number.');
    return n;
  }

  bool take(String char) {
    if (index < source.length && source[index] == char) {
      index++;
      return true;
    }
    return false;
  }

  Future<String> string() async {
    final start = index++;
    var escaped = false;
    while (index < source.length) {
      if ((index - start) % 8192 == 0)
        await Future<void>.delayed(Duration.zero);
      final char = source[index++];
      if (char == '"' && !escaped) {
        try {
          final result = jsonDecode(source.substring(start, index));
          if (result is String) return result;
        } on FormatException {
          invalid('Invalid JSON string.');
        }
        invalid('Invalid JSON string.');
      }
      escaped = char == '\\' && !escaped;
    }
    invalid('Incomplete JSON string.');
  }
}

Map<String, Object?> object(Object? value, Set<String> fields) {
  if (value is! Map<String, Object?> ||
      value.keys.any((key) => !fields.contains(key)) ||
      fields.any((key) => !value.containsKey(key))) {
    invalid('Unexpected document fields.');
  }
  return value;
}

String text(Object? value, {int max = 255, int min = 1, RegExp? pattern}) {
  if (value is! String ||
      value.length < min ||
      value.length > max ||
      (pattern != null && !pattern.hasMatch(value)))
    invalid('Invalid document string.');
  return value;
}

int integer(Object? value, {int min = 0, int max = 9007199254740991}) {
  if (value is! num ||
      !value.isFinite ||
      value != value.truncateToDouble() ||
      value < min ||
      value > max)
    invalid('Invalid document integer.');
  return value.toInt();
}

List<Object?> array(Object? value, {int max = 50000, int min = 0}) {
  if (value is! List<Object?> || value.length < min || value.length > max)
    invalid('Invalid document list.');
  return value;
}

final uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
String uuid(Object? value) => text(value, max: 36, pattern: uuidPattern);
String hash(Object? value) =>
    text(value, max: 64, pattern: RegExp(r'^[a-f0-9]{64}$'));
String localeTag(Object? value) =>
    text(value, pattern: RegExp(r'^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$'));
