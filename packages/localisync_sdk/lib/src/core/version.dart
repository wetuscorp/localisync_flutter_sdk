import 'package:pub_semver/pub_semver.dart';
import 'failure.dart';
import 'json.dart';

/// Strict SemVer 2.0. Build metadata has no precedence; bounds include prereleases.
final class AppVersion implements Comparable<AppVersion> {
  AppVersion(String value) : value = value, _version = _parse(value);
  final String value;
  final Version _version;
  static final _syntax = RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );
  static Version _parse(String value) {
    if (value.length > 256 || !_syntax.hasMatch(value)) {
      throw const LocalisyncException(
        FailureCode.configuration,
        'Use a strict semantic application version.',
      );
    }
    final v = Version.parse(value.split('+').first);
    if ([v.major, v.minor, v.patch].any((part) => part > 9007199254740991))
      throw const LocalisyncException(
        FailureCode.configuration,
        'Version component exceeds the protocol limit.',
      );
    return v;
  }

  @override
  int compareTo(AppVersion other) => _version.compareTo(other._version);
}

final class Compatibility {
  Compatibility({this.min, this.max}) {
    if (min != null && max != null && min!.compareTo(max!) > 0)
      invalid('Invalid application version range.');
  }
  factory Compatibility.fromJson(Object? value) {
    final data = object(value, {'min', 'max'});
    return Compatibility(
      min: data['min'] == null ? null : AppVersion(text(data['min'], max: 256)),
      max: data['max'] == null ? null : AppVersion(text(data['max'], max: 256)),
    );
  }
  final AppVersion? min;
  final AppVersion? max;
  bool accepts(AppVersion version) =>
      (min == null || version.compareTo(min!) >= 0) &&
      (max == null || version.compareTo(max!) <= 0);
  Map<String, Object?> toJson() => {'min': min?.value, 'max': max?.value};
  bool sameAs(Compatibility other) =>
      min?.value == other.min?.value && max?.value == other.max?.value;
}
