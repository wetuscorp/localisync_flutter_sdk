"""Compile the actual Web adapters to JavaScript/Wasm and run browser acceptance."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
repository = root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
dart = Path(flutter).resolve().parent / ('dart.bat' if os.name == 'nt' else 'dart')
output = repository / '.local/flutter-browser'
output.mkdir(parents=True, exist_ok=True)
for target, filename in [('js', 'acceptance.js'), ('wasm', 'acceptance.wasm')]:
    subprocess.run([str(dart), 'compile', target, 'tool/browser_acceptance.dart', '-o', str(output / filename)], cwd=root, check=True)
subprocess.run(['node', 'test/sdk-protocol/browser.mjs'], cwd=repository, check=True)
