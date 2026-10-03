"""Build an allowlisted package archive and test an extracted runtime installation.

This is a packaging acceptance artifact, not an upload. Pub's own dry-run must also
pass on the exact candidate. Fixture, generator, native signing and test files are
intentionally absent from the package archive.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parents[1]
package = root / 'packages/localisync_sdk'
flutter = Path(os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')).resolve()
output = (root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]) / '.local/flutter-validation'
output.mkdir(parents=True, exist_ok=True)
archive = output / 'localisync_sdk-0.1.0.tar.gz'
allowed = {'README.md', 'CHANGELOG.md', 'LICENSE', 'NOTICE', 'pubspec.yaml'}
files = sorted(p for p in package.rglob('*') if p.is_file() and
               (p.relative_to(package).parts[0] in {'lib', 'licenses'} or
                p.relative_to(package).as_posix() in allowed))
with tarfile.open(archive, 'w:gz') as target:
    for path in files:
        if path.is_symlink():
            raise SystemExit('Package source must not contain symlinks')
        target.add(path, arcname=path.relative_to(package).as_posix())
with tempfile.TemporaryDirectory(prefix='localisync-package-') as temporary:
    directory = Path(temporary)
    extracted = directory / 'sdk'
    with tarfile.open(archive) as source:
        source.extractall(extracted, filter='data')
    app = directory / 'app'
    app.mkdir()
    (app / 'pubspec.yaml').write_text('''name: localisync_archive_acceptance
publish_to: none
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  localisync_sdk:
    path: ../sdk
dev_dependencies:
  flutter_test:
    sdk: flutter
''')
    (app / 'test').mkdir()
    (app / 'test/archive_test.dart').write_text('''import 'package:flutter_test/flutter_test.dart';
import 'package:localisync_sdk/core.dart';
import 'package:localisync_sdk/localisync_sdk.dart' as flutter_sdk;
void main() {
  test('extracted archive exports core and Flutter without the old core package', () {
    final bundle = TranslationBundle(fallbacks: {'en': null}, entries: {
      'en': [TranslationEntry(key: 'welcome', format: MessageFormat.plain,
        parameters: const {}, value: 'Welcome')],
    });
    expect(bundle.find('en', 'welcome')!.$1.format(const {}), 'Welcome');
    expect(flutter_sdk.LocalisyncScope, isNotNull);
  });
}
''')
    subprocess.run([str(flutter), 'pub', 'get'], cwd=app, check=True)
    subprocess.run([str(flutter), 'test'], cwd=app, check=True)
    graph = json.loads(subprocess.check_output([str(flutter), 'pub', 'deps', '--json'], cwd=app))
    sdk = next(p for p in graph['packages'] if p['name'] == 'localisync_sdk')
    forbidden = {'localisync_core', 'localisync_generator', 'analyzer', 'yaml'}
    if forbidden.intersection(sdk.get('directDependencies', sdk['dependencies'])):
        raise SystemExit('Development tooling leaked into runtime dependencies')
(output / 'archive.json').write_text(json.dumps({
    'archiveSha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'compressedBytes': archive.stat().st_size,
    'files': {p.relative_to(package).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
    'extractedInstallation': 'passed', 'source': 'local path; registry installation still required after publication',
}, indent=2) + '\n')
print('Archive and extracted installation passed.')
