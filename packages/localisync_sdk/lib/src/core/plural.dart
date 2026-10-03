import 'package:intl/intl.dart';
import 'failure.dart';
part 'cldr_rules.dart';

/// CLDR operands for a finite numeric argument. Numbers do not retain insignificant zeros.
final class PluralOperands {
  PluralOperands(num value) {
    if (!value.isFinite)
      throw const LocalisyncException(
        FailureCode.arguments,
        'Message numbers must be finite.',
      );
    n = value.abs();
    var decimal = n.toString().toLowerCase();
    if (decimal.contains('e')) {
      final parts = decimal.split('e'), exponent = int.parse(parts[1]);
      final coefficient = parts[0].split('.'), digits = coefficient.join();
      final point = coefficient[0].length + exponent;
      decimal = point <= 0
          ? '0.${'0' * (-point)}$digits'
          : point >= digits.length
          ? '$digits${'0' * (point - digits.length)}'
          : '${digits.substring(0, point)}.${digits.substring(point)}';
    }
    if (decimal.contains('.'))
      decimal = decimal
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    final parts = decimal.split('.'),
        fraction = parts.length == 2 ? parts[1] : '';
    i = n.floorToDouble();
    v = fraction.length;
    w = v;
    f = fraction.isEmpty ? 0 : num.parse(fraction);
    t = f;
  }
  late final num n, i, f, t;
  late final int v, w;
  final int c = 0, e = 0;
}

String pluralCategory(String locale, num value, {bool ordinal = false}) {
  final rules = ordinal ? _ordinalRules : _cardinalRules;
  final parts = locale.replaceAll('_', '-').split('-');
  if (parts.length > 2 && RegExp(r'^[A-Za-z]{4}$').hasMatch(parts[1]))
    parts.removeAt(1);
  var cursor =
      _cldrAliases[parts.join('-')] ??
      '${_cldrAliases[parts.first] ?? parts.first}${parts.length == 1 ? '' : '-${parts.skip(1).join('-')}'}';
  while (true) {
    final rule = rules[cursor];
    if (rule != null) return rule(PluralOperands(value));
    final hyphen = cursor.lastIndexOf('-');
    if (hyphen < 0) return 'other';
    cursor = cursor.substring(0, hyphen);
  }
}

/// Public intl API only. Locale-data fallback does not add content fallback links.
NumberFormat decimalFormatter(String locale) {
  var cursor = locale.replaceAll('-', '_');
  while (true) {
    if (NumberFormat.localeExists(cursor))
      return NumberFormat.decimalPattern(cursor);
    final split = cursor.lastIndexOf('_');
    if (split < 0) return NumberFormat.decimalPattern('en');
    cursor = cursor.substring(0, split);
  }
}
