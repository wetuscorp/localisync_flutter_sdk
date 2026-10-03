"""Run both native examples and retain non-empty machine test evidence."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time
from process_output import run_logged

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--target', default='integration_test/platform_test.dart')
parser.add_argument('--example', choices=['basic', 'gen_l10n'])
args = parser.parse_args()
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
flutter = str(Path(flutter).resolve())
output = (root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]) / '.local/flutter-validation'
output.mkdir(parents=True, exist_ok=True)
for example in [args.example] if args.example else ['basic', 'gen_l10n']:
    started = time.monotonic()
    stem = f'native-{example}-{Path(args.target).stem}'
    # Keep Flutter's default DDS: its integration runner uses extension streams.
    result = run_logged([flutter, 'test', '--machine', '--verbose', args.target, '-d', args.device],
                        root / 'examples' / example, output / f'{stem}.log', 1200)
    events = []
    for line in result.stdout.splitlines():
        try:
            value = json.loads(line)
            if isinstance(value, dict): events.append(value)
        except json.JSONDecodeError:
            pass
    test_names = {v['test']['id']: v['test']['name'] for v in events if v.get('type') == 'testStart'}
    completed = [v for v in events if v.get('type') == 'testDone'
                 and not v.get('hidden', False)
                 and not test_names.get(v.get('testID'), '(').startswith('(')]
    passed = sum(v.get('result') == 'success' and not v.get('skipped', False) for v in completed)
    success = result.returncode == 0 and passed > 0 and any(v.get('type') == 'done' and v.get('success') is True for v in events)
    (output / f'{stem}.json').write_text(json.dumps({
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'os': platform.platform(), 'target': args.target, 'example': example,
        'device': args.device, 'seconds': time.monotonic() - started,
        'passed': passed, 'exitCode': result.returncode, 'success': success,
        'skipped': sum(bool(v.get('skipped')) for v in completed),
    }, indent=2) + '\n')
    if not success:
        raise SystemExit(f'Native acceptance failed or ran zero tests: {example}')
