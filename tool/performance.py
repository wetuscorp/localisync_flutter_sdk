"""Prepare repeatable performance assets in an explicitly isolated example checkout."""
import argparse
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
repository = root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--example', required=True, type=Path, help='Path to an isolated copy of the basic example')
args = parser.parse_args()
example = args.example.resolve()
if example == root / 'examples/basic' or not (example / 'pubspec.yaml').is_file():
    raise SystemExit('Use an isolated copy of the basic example; generated large assets are not source files.')
output = repository / '.local/flutter-performance-fixtures'
subprocess.run(['node', 'test/sdk-protocol/performance-fixtures.mjs', str(output)], cwd=repository, check=True)
shutil.copytree(output, example / 'assets/performance', dirs_exist_ok=True)
manifest = example / 'pubspec.yaml'
source = manifest.read_text()
if 'assets/performance/small/' not in source:
    source = source.replace('  assets:\n', '  assets:\n    - assets/performance/small/\n    - assets/performance/icu/\n    - assets/performance/long/\n')
    manifest.write_text(source)
print('Assets prepared. Run the profile performance integration in this isolated example.')
