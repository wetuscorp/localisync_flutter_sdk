"""Measure documented local-path setup in a fresh, disposable Flutter application.

Prerequisites (Flutter, native tools and cached dependencies) are reported separately.
This automated first-translation check does not substitute for a new user's usability study.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--published-ref', help='Verify a published vX.Y.Z tag using hosted SDK dependencies, without overrides')
args = parser.parse_args()
if args.published_ref and not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', args.published_ref):
    parser.error('--published-ref must be an immutable vX.Y.Z release tag')
repository = root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
dart = Path(flutter).resolve().parent / ('dart.bat' if os.name == 'nt' else 'dart')
app = repository / '.local' / ('flutter-quickstart-' + uuid.uuid4().hex[:8])
started = time.monotonic()
subprocess.run([flutter, 'create', '--empty', '--platforms=macos', '--project-name=localisync_acceptance', str(app)], check=True)
sdk_dependency = (f'  localisync_sdk: {args.published_ref[1:]}\n' if args.published_ref else
                  f'  localisync_sdk:\n    path: {root / "packages/localisync_sdk"}\n')
generator_dependency = (f'''  localisync_generator:
    git:
      url: https://github.com/wetuscorp/localisync_flutter_sdk.git
      ref: {args.published_ref}
      path: tool/generator
''' if args.published_ref else f'''  localisync_generator:
    path: {root / 'tool/generator'}
dependency_overrides:
  # A local rehearsal must unify the generator's hosted SDK with this source copy.
  # Published-mode acceptance deliberately has no overrides.
  localisync_sdk:
    path: {root / 'packages/localisync_sdk'}
''')
(app / 'pubspec.yaml').write_text(f'''name: localisync_acceptance
publish_to: none
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
{sdk_dependency.rstrip()}
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
{generator_dependency.rstrip()}
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
print(json.dumps({'seconds': round(time.monotonic() - started, 3),
                  'mode': 'published SDK and tagged Git generator' if args.published_ref else 'local path rehearsal with SDK override',
                  'publishedRef': args.published_ref, 'dependencyOverrides': not bool(args.published_ref),
                  'prerequisites': 'installed Flutter/Xcode; warm package cache; bundled offline first translation',
                  'application': str(app.relative_to(repository))}))
