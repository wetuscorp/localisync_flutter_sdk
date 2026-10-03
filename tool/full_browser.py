"""Build and exercise both complete Flutter example UIs, including renderer selection."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
repository = root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--skip-build', action='store_true')
parser.add_argument('--build-only', action='store_true')
args = parser.parse_args()
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter: raise SystemExit('Select an installed Flutter SDK.')
if not args.skip_build:
    for example in ['basic', 'gen_l10n']:
        for mode in ['js', 'wasm']:
            output = repository / '.local/flutter-web' / example / mode
            command = [flutter, 'build', 'web', '--release', '--no-web-resources-cdn', '--target=integration_test/browser_app.dart', f'--output={output}']
            if mode == 'wasm': command.append('--wasm')
            subprocess.run(command, cwd=root / 'examples' / example, check=True)
if not args.build_only:
    subprocess.run(['node', 'test/sdk-protocol/flutter-browser.mjs'], cwd=repository, check=True)
