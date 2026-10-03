import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/src/platform/cache_web.dart';
import 'package:localisync_sdk/src/platform/transport_web.dart';
import '../packages/localisync_sdk/test/support/delivery_fixture.dart';

Future<void> main() async {
  final fixture = jsonDecode(deliveryFixture) as Map<String, Object?>;
  final query = Uri.parse(web.window.location.href).queryParameters;
  final config = LocalisyncConfig(
    projectId: fixture['projectId']! as String,
    distributionId: fixture['distributionId']! as String,
    channel: Channel.preview,
    addresses: [
      Uri.parse(web.window.location.origin),
      Uri.parse(query['secondary']!),
    ],
    readKey: 'public-browser-fixture',
    trustedKeys: {'test-1': fixture['publicKey']! as String},
    appVersion: '1.0.0+browser',
    allowDevelopmentHttp: true,
    locale: 'tr',
    requestTimeout: const Duration(seconds: 2),
    refreshTimeout: const Duration(seconds: 12),
    bundled: TranslationBundle(
      fallbacks: {'en': null, 'tr': 'en'},
      entries: {
        'en': [
          TranslationEntry(
            key: 'plain',
            format: MessageFormat.plain,
            parameters: {},
            value: 'Bundled startup',
          ),
        ],
      },
    ),
  );
  final client = LocalisyncClient(
    config: config,
    transport: PlatformDeliveryTransport(),
    cache: IndexedDbDeliveryCache(databaseName: 'acceptance-${query['id']}'),
  );
  try {
    if (client.translate('plain') != 'Bundled startup')
      throw StateError('Initial frame');
    final result = await client.ready;
    if (result.outcome == UpdateOutcome.failed && query['offline'] != 'true')
      throw result.failure!;
    if (client.translate('plain') != 'Published text' ||
        client.translate('rank', arguments: {'count': 22}) != '22nd')
      throw StateError('Content');
    if (!result.persisted) throw StateError('Persistence');
    if (query['offline'] != 'true') {
      final refresh = await client.refresh();
      if (refresh.outcome != UpdateOutcome.unchanged) throw StateError('ETag');
      await client.setLocale('en');
      if (client.locale != 'en') throw StateError('Locale');
    }
    web.document.body!.textContent = 'passed';
  } on Object catch (error) {
    web.document.body!.textContent = error is LocalisyncException
        ? error.toString()
        : 'Browser acceptance failed: ${error.runtimeType}';
  } finally {
    await client.dispose();
  }
}
