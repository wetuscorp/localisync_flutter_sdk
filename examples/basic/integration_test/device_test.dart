import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../../../test_support/device_acceptance.dart';
import '../lib/main.dart';
import '../lib/generated/localisync_messages.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real device sockets, cache and application state survive failures',
    (tester) async {
      await exerciseDevice(
        tester,
        createLocalisyncBundle(),
        (client) => ExampleRoot(client: client),
      );
    },
  );
}
