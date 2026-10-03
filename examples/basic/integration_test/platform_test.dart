import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'package:localisync_sdk/src/platform/factory_io.dart'
    if (dart.library.js_interop) 'package:localisync_sdk/src/platform/factory_web.dart'
    as platform;
import '../../../test_support/platform_acceptance.dart';
import '../lib/main.dart';
import '../lib/generated/localisync_messages.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'platform storage, verified activation and offline restart preserve application state',
    (tester) async {
      final transport = AcceptanceTransport();
      LocalisyncClient create(AcceptanceTransport transport) =>
          LocalisyncClient(
            config: acceptanceConfig(createLocalisyncBundle()),
            transport: transport,
            cache: platform.createCache(),
            preparer: platform.createPreparer(),
            verification: platform.createVerification(),
          );
      final client = create(transport);
      await tester.pumpWidget(ExampleRoot(client: client));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Keep this draft');
      await tester.runAsync(() async {
        expect((await client.ready).outcome, isNot(UpdateOutcome.failed));
        expect(
          client.translate('greeting', arguments: {'name': 'Ada'}),
          'Merhaba Ada',
        );
        await client.refresh();
      });
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await client.dispose();
      final offline = create(AcceptanceTransport()..offline = true);
      await tester.runAsync(() async {
        await offline.ready;
        expect(
          offline.translate('greeting', arguments: {'name': 'Ada'}),
          'Merhaba Ada',
        );
        expect(offline.status.persisted, true);
      });
      await offline.dispose();
    },
  );
}
