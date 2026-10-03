"""Measure documented local-path setup in a fresh, disposable Flutter application.

Prerequisites (Flutter, native tools and cached dependencies) are reported separately.
This automated first-translation check does not substitute for a new user's usability study.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

root = Path(__file__).resolve().parents[1]
repository = root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
dart = Path(flutter).resolve().parent / ('dart.bat' if os.name == 'nt' else 'dart')
app = repository / '.local' / ('flutter-quickstart-' + uuid.uuid4().hex[:8])
started = time.monotonic()
subprocess.run([flutter, 'create', '--empty', '--platforms=macos', '--project-name=localisync_acceptance', str(app)], check=True)
(app / 'pubspec.yaml').write_text(f'''name: localisync_acceptance
publish_to: none
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  localisync_sdk:
    path: {root / 'packages/localisync_sdk'}
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  localisync_generator:
    path: {root / 'tool/generator'}
flutter:
  uses-material-design: true
''')
(app / 'lib/app_en.arb').write_text(json.dumps({'@@locale': 'en', 'welcome': 'First Localisync translation'}))
(app / 'localisync.yaml').write_text('arb:\n  en: lib/app_en.arb\nfallbacks:\n  en: null\noutput: lib/messages.dart\n')
subprocess.run([flutter, 'pub', 'get'], cwd=app, check=True)
subprocess.run([str(dart), 'run', 'localisync_generator:generate', 'localisync.yaml'], cwd=app, check=True)
fixture = json.loads((repository / 'test/sdk-protocol/delivery.json').read_text())
(app / 'lib/main.dart').write_text('''import 'package:flutter/material.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'messages.dart';
// The test supplies a config; a real application uses Distribution SDK setup.
void showTranslations(LocalisyncClient client) => runApp(LocalisyncScope(
  client: client, child: const MaterialApp(home: FirstTranslation())));
class FirstTranslation extends StatelessWidget {
  const FirstTranslation({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Text(
    LocalisyncMessages(LocalisyncScope.of(context)).welcome));
}
void main() => throw StateError('Supply SDK setup before running this acceptance-only app.');
''')
(app / 'integration_test').mkdir()
(app / 'integration_test/first_test.dart').write_text('''import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import '../lib/main.dart';
import '../lib/messages.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('first translation is available before any network request', (tester) async {
    final client = createLocalisyncClient(LocalisyncConfig(
      projectId: ''' + json.dumps(fixture['projectId']) + ''',
      distributionId: ''' + json.dumps(fixture['distributionId']) + ''',
      trustedKeys: {'test-1': ''' + json.dumps(fixture['publicKey']) + '''},
      channel: Channel.preview, appVersion: '1.0.0', readKey: 'acceptance-only',
      addresses: [Uri.parse('https://primary.invalid'), Uri.parse('https://secondary.invalid')],
      bundled: createLocalisyncBundle(), contracts: localisyncContracts(), locale: 'en',
      updatePolicy: UpdatePolicy.manual));
    showTranslations(client);
    await tester.pump();
    expect(find.text('First Localisync translation'), findsOneWidget);
    await tester.runAsync(() async { await client.ready; await client.dispose(); });
  });
}
''')
subprocess.run([flutter, 'test', 'integration_test/first_test.dart', '-d', 'macos'], cwd=app, check=True)
print(json.dumps({'seconds': round(time.monotonic() - started, 3), 'mode': 'fresh app, local path dependencies, macOS integration test',
                  'prerequisites': 'installed Flutter/Xcode; warm package cache; bundled offline first translation',
                  'application': str(app.relative_to(repository))}))
