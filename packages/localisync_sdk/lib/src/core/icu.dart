import 'dart:convert';
import 'package:intl/intl.dart';
import 'failure.dart';
import 'plural.dart';
import 'protocol.dart';

/// Prepared immutable message. Parsing/contract validation happens once before activation.
final class CompiledMessage {
  CompiledMessage._(this.entry, this._nodes, this._numberFormat, this.locale);
  factory CompiledMessage(TranslationEntry entry, String locale) =>
      MessageCompiler(locale).compile(entry);
  final TranslationEntry entry;
  final List<MessageNode> _nodes;
  final NumberFormat? _numberFormat;
  final String locale;
  String format(Map<String, Object> arguments) {
    if (arguments.length != entry.parameters.length ||
        entry.parameters.entries.any(
          (p) => switch (p.value) {
            ParameterType.text => arguments[p.key] is! String,
            ParameterType.number =>
              arguments[p.key] is! num || !(arguments[p.key]! as num).isFinite,
          },
        ))
      throw const LocalisyncException(
        FailureCode.arguments,
        'Message arguments do not match the declared contract.',
      );
    if (entry.format == MessageFormat.plain) return entry.value!;
    final output = StringBuffer();
    void render(List<MessageNode> nodes, num? pound) {
      for (final node in nodes) {
        switch (node) {
          case LiteralNode(:final text):
            output.write(text);
          case ArgumentNode(:final name):
            output.write(arguments[name]);
          case PoundNode():
            output.write(pound == null ? '#' : _numberFormat!.format(pound));
          case ChoiceNode(
            :final name,
            :final kind,
            :final offset,
            :final options,
          ):
            final value = arguments[name];
            if (kind == 'select') {
              render(options[value] ?? options['other']!, pound);
            } else {
              if (value is! num)
                throw const LocalisyncException(
                  FailureCode.arguments,
                  'A plural argument must be numeric.',
                );
              final exact = node.exactOptions[value];
              final adjusted = value - offset;
              render(
                exact ??
                    options[pluralCategory(
                      locale,
                      adjusted,
                      ordinal: kind == 'selectordinal',
                    )] ??
                    options['other']!,
                adjusted,
              );
            }
        }
      }
    }

    render(_nodes, null);
    return output.toString();
  }
}

/// Scoped to one locale in one prepared bundle, never a global formatter cache.
/// Formatting is synchronous: callers cannot overlap access to the private formatter.
final class MessageCompiler {
  MessageCompiler(this.locale);
  final String locale;
  NumberFormat? _numberFormat;
  CompiledMessage compile(TranslationEntry entry) {
    final value = entry.value;
    if (value == null) invalid('A missing message cannot be compiled.');
    final nodes = entry.format == MessageFormat.plain
        ? <MessageNode>[LiteralNode(value)]
        : _IcuReader(value, entry.parameters).parse();
    return CompiledMessage._(
      entry,
      List.unmodifiable(nodes),
      entry.format == MessageFormat.plain
          ? null
          : (_numberFormat ??= decimalFormatter(locale)),
      locale,
    );
  }
}

sealed class MessageNode {
  const MessageNode();
}

final class LiteralNode extends MessageNode {
  const LiteralNode(this.text);
  final String text;
}

final class ArgumentNode extends MessageNode {
  const ArgumentNode(this.name);
  final String name;
}

final class PoundNode extends MessageNode {
  const PoundNode();
}

final class ChoiceNode extends MessageNode {
  ChoiceNode(
    this.name,
    this.kind,
    this.offset,
    Map<String, List<MessageNode>> options,
  ) : options = Map.unmodifiable(
        options.map((k, v) => MapEntry(k, List<MessageNode>.unmodifiable(v))),
      ),
      exactOptions = Map.unmodifiable({
        for (final item in options.entries.where(
          (e) => kind != 'select' && e.key.startsWith('='),
        ))
          num.parse(item.key.substring(1)): List<MessageNode>.unmodifiable(
            item.value,
          ),
      });
  final String name, kind;
  final num offset;
  final Map<String, List<MessageNode>> options;
  final Map<num, List<MessageNode>> exactOptions;
}

final class _IcuReader {
  _IcuReader(this.source, this.contract) {
    if (utf8.encode(source).length > DeliveryLimits.valueBytes) fail();
  }
  final String source;
  final Map<String, ParameterType> contract;
  final used = <String>{};
  int index = 0, nodes = 0;
  Never fail() => throw const LocalisyncException(
    FailureCode.protocol,
    'Invalid or unsupported ICU message.',
  );
  void space() {
    while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
      index++;
    }
  }

  bool take(String s) {
    if (source.startsWith(s, index)) {
      index += s.length;
      return true;
    }
    return false;
  }

  String identifier() {
    space();
    final m = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(source, index);
    if (m == null) fail();
    index = m.end;
    return m.group(0)!;
  }

  List<MessageNode> parse() {
    final result = message(0, false, false);
    if (index != source.length || used.length != contract.length) fail();
    return result;
  }

  void add(List<MessageNode> result, MessageNode node) {
    if (++nodes > 1000) fail();
    result.add(node);
  }

  List<MessageNode> message(int depth, bool nested, bool pound) {
    final result = <MessageNode>[];
    var buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        add(result, LiteralNode(buffer.toString()));
        buffer = StringBuffer();
      }
    }

    while (index < source.length) {
      final c = source[index];
      if (c == '}') {
        if (!nested) {
          buffer.write(c);
          index++;
          continue;
        }
        flush();
        index++;
        return result;
      }
      if (c == "'") {
        index++;
        if (take("'")) {
          buffer.write("'");
          continue;
        }
        if (index < source.length &&
            (source[index] == '{' ||
                source[index] == '}' ||
                source[index] == '<' ||
                (pound && source[index] == '#'))) {
          while (index < source.length) {
            if (take("'")) {
              if (take("'")) {
                buffer.write("'");
              } else {
                break;
              }
            } else {
              buffer.write(source[index++]);
            }
          }
        } else {
          buffer.write("'");
        }
        continue;
      }
      if (c == '#' && pound) {
        flush();
        index++;
        add(result, const PoundNode());
        continue;
      }
      if (c == '<' && RegExp(r'^</?[A-Za-z]').hasMatch(source.substring(index)))
        fail();
      if (c != '{') {
        buffer.write(c);
        index++;
        continue;
      }
      flush();
      index++;
      if (depth >= 10) fail();
      final name = identifier();
      if (!contract.containsKey(name)) fail();
      used.add(name);
      space();
      if (take('}')) {
        add(result, ArgumentNode(name));
        continue;
      }
      if (!take(',')) fail();
      final kind = identifier();
      space();
      if (!take(',')) fail();
      space();
      if (!['select', 'plural', 'selectordinal'].contains(kind)) fail();
      if (contract[name] !=
          (kind == 'select' ? ParameterType.text : ParameterType.number))
        fail();
      num offset = 0;
      if (kind != 'select' && take('offset:')) {
        space();
        final m = RegExp(r'[+-]?[0-9]+').matchAsPrefix(source, index);
        if (m == null) fail();
        offset = num.parse(m.group(0)!);
        index = m.end;
        space();
      }
      final options = <String, List<MessageNode>>{};
      while (!take('}')) {
        space();
        String selector;
        if (kind != 'select' && take('=')) {
          final m = RegExp(r'[+-]?[0-9]+').matchAsPrefix(source, index);
          if (m == null) fail();
          selector = '=${m.group(0)}';
          index = m.end;
        } else {
          final m = RegExp(r'[^\s{}]+').matchAsPrefix(source, index);
          if (m == null) fail();
          selector = m.group(0)!;
          if (RegExp(r'[!-/:-@\[-^`{-~]').hasMatch(selector)) fail();
          index = m.end;
        }
        if (kind != 'select' &&
            !selector.startsWith('=') &&
            !['zero', 'one', 'two', 'few', 'many', 'other'].contains(selector))
          fail();
        if (options.containsKey(selector)) fail();
        space();
        if (!take('{')) fail();
        options[selector] = message(depth + 1, true, kind != 'select');
        space();
        if (index >= source.length) fail();
      }
      if (!options.containsKey('other')) fail();
      add(result, ChoiceNode(name, kind, offset, options));
    }
    if (nested) fail();
    flush();
    return result;
  }
}
