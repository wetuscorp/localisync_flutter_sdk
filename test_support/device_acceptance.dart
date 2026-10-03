import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/cache_io.dart';
import 'package:localisync_sdk/src/platform/factory_io.dart' as platform;
import 'package:localisync_sdk/src/platform/transport_io.dart';
import 'loopback_delivery.dart';
import 'platform_acceptance.dart';

Future<void> exerciseDevice(
  WidgetTester tester,
  TranslationBundle bundled,
  Widget Function(LocalisyncClient) app,
) async {
  final directory = await Directory.systemTemp.createTemp('localisync-device-');
  final delivery = await LoopbackDelivery.start();
  LocalisyncClient create({
    ActivationPolicy activation = ActivationPolicy.immediate,
  }) => LocalisyncClient(
    config: delivery.config(bundled, activation: activation),
    transport: PlatformDeliveryTransport(),
    cache: FileDeliveryCache(directory: () async => directory),
    preparer: platform.createPreparer(),
    verification: platform.createVerification(),
  );
  final clients = <LocalisyncClient>[];
  try {
    final client = create(activation: ActivationPolicy.manual);
    clients.add(client);
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    expect(delivery.requests, 0);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    // WidgetTester.enterText uses a debug-only client ID with the real IME.
    // Profile acceptance injects the edit through EditableText's public API.
    tester
        .state<EditableTextState>(find.byType(EditableText).first)
        .updateEditingValue(
          const TextEditingValue(
            text: 'Device draft',
            selection: TextSelection.collapsed(offset: 12),
          ),
        );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Device draft',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open another screen'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      delivery.faults[0] = DeliveryFault.offline;
      final result = await client.refresh();
      expect(result.outcome, isNot(UpdateOutcome.failed));
      expect(client.hasPending, true);
      await client.activatePending();
      expect(client.translate('plain'), 'Published text');
    });
    await tester.pumpAndSettle();
    expect(find.text('Preserved route'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Device draft',
    );
    await tester.runAsync(() async {
      await client.setLocale('tr');
      expect(
        client.translate('greeting', arguments: {'name': 'Ada'}),
        'Merhaba Ada',
      );
      final count = delivery.requests;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(delivery.requests, count);
      delivery.faults[0] = DeliveryFault.none;
      delivery.catalog = fixture['rollbackJws']! as String;
      await client.refresh();
      if (client.hasPending) await client.activatePending();
      expect(client.status.revision, 3);
      for (final fault in [
        DeliveryFault.offline,
        DeliveryFault.signature,
        DeliveryFault.truncated,
        DeliveryFault.delayed,
        DeliveryFault.stale,
      ]) {
        delivery.faults.fillRange(0, 2, fault);
        final result = await client.refresh();
        expect(result.outcome, UpdateOutcome.failed, reason: fault.name);
        expect(client.translate('plain'), 'Published text');
        expect(client.status.revision, 3);
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await client.dispose();
    await tester.runAsync(() async {
      delivery.faults.fillRange(0, 2, DeliveryFault.offline);
      final restored = create();
      clients.add(restored);
      await restored.ready;
      expect(restored.resolve('plain').source, ContentSource.remote);
      expect(restored.status.persisted, true);
      await restored.dispose();
      await directory.delete(recursive: true);
      await directory.create();
      delivery.faults.fillRange(0, 2, DeliveryFault.hash);
      final corrupt = create();
      clients.add(corrupt);
      await corrupt.ready;
      expect((await corrupt.refresh()).outcome, UpdateOutcome.failed);
      expect(corrupt.resolve('plain').source, isNot(ContentSource.remote));
    });
  } finally {
    for (final client in clients) await client.dispose();
    await delivery.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
