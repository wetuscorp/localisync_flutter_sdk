import 'dart:convert';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'generated/localisync_messages.dart';

/// Public SDK setup and a distribution read key are supplied at build time.
/// Never supply a management credential or signing private key here.
LocalisyncConfig exampleConfiguration() {
  const source = String.fromEnvironment('LOCALISYNC_CONFIG');
  if (source.isEmpty)
    throw const FormatException(
      'Supply LOCALISYNC_CONFIG using --dart-define-from-file. See the example README.',
    );
  final value = jsonDecode(source);
  if (value is! Map<String, Object?>)
    throw const FormatException('Expected SDK configuration.');
  final addresses = value['addresses'], keys = value['trustedKeys'];
  if (addresses is! List<Object?> || keys is! Map<String, Object?>)
    throw const FormatException('Missing public SDK addresses or trust keys.');
  String text(Object? v) {
    if (v is! String) throw const FormatException('Invalid SDK setup field.');
    return v;
  }

  final channel = text(value['channel']);
  if (!['preview', 'production'].contains(channel))
    throw const FormatException('Invalid channel.');
  return LocalisyncConfig(
    projectId: text(value['projectId']),
    distributionId: text(value['distributionId']),
    channel: Channel.values.byName(channel),
    addresses: addresses.map((v) => Uri.parse(text(v))).toList(),
    trustedKeys: keys.map((k, v) => MapEntry(k, text(v))),
    readKey: text(value['readKey']),
    appVersion: text(value['appVersion']),
    locale: 'en',
    bundled: createLocalisyncBundle(),
    contracts: localisyncContracts(),
    allowDevelopmentHttp: value['allowDevelopmentHttp'] == true,
  );
}
