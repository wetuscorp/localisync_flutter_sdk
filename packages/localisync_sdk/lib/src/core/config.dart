import 'diagnostics.dart';
import 'content.dart';
import 'failure.dart';
import 'json.dart';
import 'protocol.dart';
import 'version.dart';

enum UpdatePolicy { onStart, manual }

enum ActivationPolicy { immediate, manual }

final class LocalisyncConfig {
  LocalisyncConfig({
    required this.projectId,
    required this.distributionId,
    required this.channel,
    required List<Uri> addresses,
    required this.readKey,
    required Map<String, String> trustedKeys,
    required String appVersion,
    required this.bundled,
    required this.locale,
    this.updatePolicy = UpdatePolicy.onStart,
    this.activationPolicy = ActivationPolicy.immediate,
    this.allowDevelopmentHttp = false,
    this.requestTimeout = const Duration(seconds: 15),
    this.refreshTimeout = const Duration(seconds: 60),
    this.diagnostics,
    this.cacheBytes = 256 * 1024 * 1024,
    Map<String, TranslationEntry> contracts = const {},
  }) : addresses = List.unmodifiable(addresses),
       trustedKeys = Map.unmodifiable(trustedKeys),
       appVersion = AppVersion(appVersion),
       contracts = Map.unmodifiable(contracts) {
    diagnostics?.validate(allowDevelopmentHttp);
    try {
      uuid(projectId);
      uuid(distributionId);
      localeTag(locale);
      SignatureVerifier(trustedKeys);
    } on LocalisyncException catch (error) {
      throw LocalisyncException(FailureCode.configuration, error.message);
    }
    if (addresses.length != 2 ||
        trustedKeys.isEmpty ||
        readKey.isEmpty ||
        readKey.contains(RegExp(r'[\r\n]')) ||
        requestTimeout <= Duration.zero ||
        refreshTimeout < requestTimeout ||
        cacheBytes < DeliveryLimits.bytes)
      bad();
    for (final address in addresses) {
      final local = [
        'localhost',
        '127.0.0.1',
        '::1',
        '10.0.2.2',
      ].contains(address.host);
      if (address.userInfo.isNotEmpty ||
          address.hasQuery ||
          address.hasFragment ||
          !['', '/'].contains(address.path) ||
          address.host.isEmpty ||
          !(address.scheme == 'https' ||
              allowDevelopmentHttp && local && address.scheme == 'http'))
        bad();
    }
    if (addresses.map((a) => a.origin).toSet().length != 2) bad();
    if (!bundled.fallbacks.containsKey(locale)) bad();
  }
  Never bad() => throw const LocalisyncException(
    FailureCode.configuration,
    'Invalid SDK configuration. Use two distinct HTTPS origins, trust keys and a bundled locale.',
  );
  final DiagnosticsConfig? diagnostics;
  final String projectId, distributionId, readKey, locale;
  final Channel channel;
  final List<Uri> addresses;
  final Map<String, String> trustedKeys;
  final Map<String, TranslationEntry> contracts;
  final AppVersion appVersion;
  final TranslationBundle bundled;
  final UpdatePolicy updatePolicy;
  final ActivationPolicy activationPolicy;
  final bool allowDevelopmentHttp;
  final Duration requestTimeout, refreshTimeout;
  final int cacheBytes;
  String get cacheScope =>
      '$projectId/$distributionId/${channel.name}/${(addresses.map((v) => v.origin).toList()..sort()).join('|')}';
}
