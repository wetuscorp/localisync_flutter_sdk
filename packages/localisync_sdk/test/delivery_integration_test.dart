@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/cache_io.dart';
import 'package:localisync_sdk/src/platform/preparer_io.dart';
import 'package:localisync_sdk/src/platform/transport_io.dart';
import 'package:localisync_sdk/src/platform/verification_io.dart';

// This test reads an ephemeral configuration created by the isolated publishing
// integration test. Credentials never enter test names, assertions or diagnostics.
void main() {
  const path = String.fromEnvironment('LOCALISYNC_TEST_CONFIG');
  test(
    'real delivery, durable restart and verified revision',
    () async {
      final input =
          jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
      final config = LocalisyncConfig(
        projectId: input['projectId']! as String,
        distributionId: input['distributionId']! as String,
        channel: Channel.production,
        addresses: (input['addresses']! as List<Object?>)
            .map((v) => Uri.parse(v! as String))
            .toList(),
        readKey: input['readKey']! as String,
        trustedKeys: (input['trustedKeys']! as Map<String, Object?>).map(
          (k, v) => MapEntry(k, v! as String),
        ),
        appVersion: '1.2.3+integration',
        allowDevelopmentHttp: true,
        locale: 'en',
        requestTimeout: const Duration(seconds: 2),
        refreshTimeout: const Duration(seconds: 15),
        bundled: TranslationBundle(
          fallbacks: {'en': null},
          entries: {
            'en': [
              TranslationEntry(
                key: 'welcome',
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
        cache: FileDeliveryCache(
          directory: () async => Directory(input['cacheDirectory']! as String),
        ),
        preparer: const PlatformContentPreparer(),
        verification: const IsolateVerification(),
      );
      addTearDown(client.dispose);
      expect(client.translate('welcome'), 'Bundled startup');
      final result = await client.ready;
      expect(
        result.outcome == UpdateOutcome.failed,
        input['offline'],
        reason: result.failure?.toString(),
      );
      expect(client.translate('welcome'), input['expected']);
      expect(client.status.revision, input['revision']);
      expect(client.releaseId, input['releaseId']);
      expect(client.resolve('welcome').source, ContentSource.remote);
      expect(result.persisted, true);
    },
    skip: path.isEmpty
        ? 'Run through the isolated publishing SDK integration command.'
        : false,
  );
}
