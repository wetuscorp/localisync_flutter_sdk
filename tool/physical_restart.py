"""Verify cache across two signed iPhone application processes without uninstalling.

Use an isolated checkout whose personal signing settings are already configured.
The test application alone is terminated; device identifiers are not saved in source.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--example', type=Path, required=True)
parser.add_argument('--device', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
example = args.example.resolve()
if example in [(root / 'examples' / name).resolve() for name in ['basic', 'gen_l10n']]:
    raise SystemExit('Use an isolated, locally signed example checkout.')
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN', 'flutter')
args.output.mkdir(parents=True, exist_ok=True)
results = []
for phase in ['prepare', 'restore']:
    path = args.output / f'{example.name}-restart-{phase}.log'
    with path.open('w', encoding='utf-8') as log:
        subprocess.run([flutter, 'build', 'ios', '--profile',
                        '--target=integration_test/restart_test.dart',
                        f'--dart-define=LOCALISYNC_RESTART_PHASE={phase}'],
                       cwd=example, stdout=log, stderr=subprocess.STDOUT, check=True)
        # The default drive cleanup uninstalls the app, invalidating restart tests.
        subprocess.run([flutter, 'drive', '--driver=../basic/test_driver/performance.dart',
                        '--use-application-binary=build/ios/iphoneos/Runner.app',
                        '--profile', '--keep-app-running', '-d', args.device],
                       cwd=example, stdout=log, stderr=subprocess.STDOUT, check=True)
    match = re.search(r'LOCALISYNC_RESTART (\{[^\n]+\})', path.read_text(encoding='utf-8'))
    if not match:
        raise SystemExit(f'Missing successful restart assertion: {phase}')
    record = json.loads(match.group(1))
    if record['phase'] != phase or not isinstance(record['pid'], int):
        raise SystemExit('Invalid process restart report.')
    subprocess.run(['xcrun', 'devicectl', 'device', 'process', 'terminate',
                    '--device', args.device, '--pid', str(record['pid']), '--kill'], check=True)
    results.append(record)
    print(f'{example.name}: {phase} passed', flush=True)
if results[0]['pid'] == results[1]['pid']:
    raise SystemExit('The test did not restart the application process.')
(args.output / f'{example.name}-restart.json').write_text(
    json.dumps({'example': example.name, 'mode': 'profile', 'phases': results}, indent=2) + '\n')
