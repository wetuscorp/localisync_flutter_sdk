"""Pinned, isolated documentation tooling; does not alter SDK dependency resolution."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
flutter = Path(os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')).resolve()
dart = flutter.parent / ('dart.bat' if os.name == 'nt' else 'dart')
env = dict(os.environ, PUB_CACHE=str((root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]) / '.local/dartdoc-cache'))
# 9.0.8 fixes @docImport CRLF offset drift; 9.0.9 includes that fix.
subprocess.run([str(dart), 'pub', 'global', 'activate', 'dartdoc', '9.0.9'], env=env, check=True)
for name in ['localisync_sdk']:
    package = root / 'packages' / name
    subprocess.run([str(dart), 'pub', 'global', 'run', 'dartdoc'], cwd=package, env=env, check=True)
    subprocess.run([str(dart), 'pub', 'publish', '--dry-run'], cwd=package, check=True)
