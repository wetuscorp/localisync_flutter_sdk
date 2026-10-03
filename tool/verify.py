"""Run SDK checks from their required package directories; never changes global Flutter."""
import argparse
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import time
from process_output import run_logged

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--browser', action='store_true')
parser.add_argument('--downgrade', action='store_true')
args = parser.parse_args()
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
flutter = Path(flutter).resolve()
dart = flutter.parent / ('dart.bat' if os.name == 'nt' else 'dart')
evidence = (root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]) / '.local/flutter-validation'
evidence.mkdir(parents=True, exist_ok=True)
report = {'os': platform.platform(), 'mode': 'minimum' if args.downgrade else 'normal', 'commands': []}
report['commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
# First use can bootstrap the Flutter tool and print non-JSON setup progress.
subprocess.run([str(flutter), '--version'], check=True)
report['flutter'] = json.loads(subprocess.check_output([str(flutter), '--version', '--machine'], text=True))
report_path = evidence / ('verify-minimum.json' if args.downgrade else 'verify-normal.json')

def run(command, cwd=root, tests=False):
    command = [str(item) for item in command]
    started = time.monotonic()
    mode = 'minimum' if args.downgrade else 'normal'
    result = run_logged(command, cwd, evidence / f'{mode}-{len(report["commands"]):02d}.log', 600)
    entry = {'command': command, 'seconds': time.monotonic() - started, 'exitCode': result.returncode}
    if tests:
        events = []
        for line in result.stdout.splitlines():
            try:
                event = json.loads(line)
                if isinstance(event, dict): events.append(event)
            except json.JSONDecodeError:
                pass
        test_names = {event['test']['id']: event['test']['name'] for event in events if event.get('type') == 'testStart'}
        completed = [event for event in events if event.get('type') == 'testDone'
                     and not event.get('hidden', False)
                     and not test_names.get(event.get('testID'), '(').startswith('(')]
        entry['passed'] = sum(event.get('result') == 'success' and not event.get('skipped', False) for event in completed)
        entry['skipped'] = sum(bool(event.get('skipped')) for event in completed)
        if not entry['passed'] or not any(event.get('type') == 'done' and event.get('success') is True for event in events):
            entry['exitCode'] = entry['exitCode'] or 1
    report['commands'].append(entry)
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    if entry['exitCode']:
        raise SystemExit(f'Acceptance command failed or produced no completed tests: {command}')

# Resolve first when changing toolchains: Flutter pins may legitimately differ.
# The downgrade check restores this toolchain's baseline, never a different SDK's lock.
if args.downgrade:
    run([flutter, 'pub', 'get'])
lock = root / 'pubspec.lock'
original = lock.read_bytes() if lock.exists() else None
try:
    run([flutter, 'pub', 'downgrade' if args.downgrade else 'get'])
    run([dart, 'format', '--output=none', '--set-exit-if-changed', 'packages', 'examples', 'tool', 'test_support'])
    run([flutter, 'analyze', '--no-pub'])
    run([dart, 'test', '--reporter=json', 'test/core_test.dart', 'test/conformance_test.dart'], root / 'packages/localisync_sdk', tests=True)
    run([dart, 'test', '--reporter=json'], root / 'tool/generator', tests=True)
    run([flutter, 'test', '--no-pub', '--machine', 'test/diagnostics_test.dart', 'test/cache_io_test.dart', 'test/preparer_io_test.dart', 'test/widget_test.dart'], root / 'packages/localisync_sdk', tests=True)
    if args.browser:
        # These browser storage tests use no Flutter engine or widgets.
        run([dart, 'test', '--reporter=json', '--platform=chrome', 'test/cache_web_test.dart'], root / 'packages/localisync_sdk', tests=True)
finally:
    if args.downgrade and original is not None:
        lock.write_bytes(original)
        run([flutter, 'pub', 'get', '--enforce-lockfile'])
