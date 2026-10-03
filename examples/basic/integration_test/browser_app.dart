import '../../../test_support/browser_application.dart';
import '../lib/generated/localisync_messages.dart';
import '../lib/main.dart';

void main() => runBrowserApplication(
  createLocalisyncBundle(),
  (client) => ExampleRoot(client: client),
);
