import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/cache_io.dart';
import 'package:localisync_sdk/src/platform/factory_io.dart' as platform;
import 'package:localisync_sdk/src/platform/transport_io.dart';
import 'loopback_delivery.dart';
import 'platform_acceptance.dart';

/// Two separate application processes, not merely two client instances.
Future<void> exerciseProcessRestart(TranslationBundle bundled) async {
  const phase = String.fromEnvironment('LOCALISYNC_RESTART_PHASE');
  if (!['prepare', 'restore'].contains(phase)) {
    throw StateError('Choose prepare or restore for the process restart test.');
  }
  final directory = Directory(
    '${Directory.systemTemp.path}/localisync-restart-acceptance',
  );
  final marker = File('${directory.path}/process.json');
  LoopbackDelivery? server;
  late List<Uri> addresses;
  if (phase == 'prepare') {
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create();
    server = await LoopbackDelivery.start();
    addresses = server.servers
        .map((s) => Uri.parse('http://127.0.0.1:${s.port}'))
        .toList();
  } else {
    final record =
        jsonDecode(await marker.readAsString()) as Map<String, Object?>;
    expect(
      record['pid'],
      isNot(pid),
      reason: 'Restore must run in a different OS process.',
    );
    addresses = (record['addresses']! as List<Object?>)
        .map((v) => Uri.parse(v! as String))
        .toList();
  }
  final client = LocalisyncClient(
    config: LocalisyncConfig(
      projectId: fixture['projectId']! as String,
      distributionId: fixture['distributionId']! as String,
      channel: Channel.preview,
      addresses: addresses,
      readKey: 'device-fixture',
      trustedKeys: {'test-1': fixture['publicKey']! as String},
      appVersion: '1.0.0',
      bundled: bundled,
      locale: 'en',
      updatePolicy: UpdatePolicy.manual,
      allowDevelopmentHttp: true,
    ),
    transport: PlatformDeliveryTransport(),
    cache: FileDeliveryCache(
      directory: () async => Directory('${directory.path}/cache'),
    ),
    preparer: platform.createPreparer(),
    verification: platform.createVerification(),
  );
  try {
    await client.ready;
    if (phase == 'prepare') {
      expect((await client.refresh()).outcome, UpdateOutcome.updated);
      await marker.writeAsString(
        jsonEncode({
          'pid': pid,
          'addresses': addresses.map((v) => v.toString()).toList(),
        }),
        flush: true,
      );
    }
    // No server is started and no refresh is requested in the restore process.
    expect(client.resolve('plain').source, ContentSource.remote);
    expect(client.translate('plain'), 'Published text');
    expect(client.status.persisted, true);
    debugPrint(
      'LOCALISYNC_RESTART ${jsonEncode({'phase': phase, 'pid': pid})}',
    );
  } finally {
    await client.dispose();
    await server?.close();
    if (phase == 'restore') await directory.delete(recursive: true);
  }
}
