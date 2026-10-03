import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../../../test_support/process_restart.dart';
import '../lib/generated/localisync_messages.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('retains verified cache across OS processes', (tester) async {
    await tester.runAsync(
      () => exerciseProcessRestart(createLocalisyncBundle()),
    );
  });
}
