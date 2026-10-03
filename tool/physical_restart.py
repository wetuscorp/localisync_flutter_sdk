"""Verify cache across two signed iPhone application processes without uninstalling.

Use an isolated checkout whose personal signing settings are already configured.
The test application alone is terminated; device identifiers are not saved in source.
"""
import argparse
import json
import os
import plistlib
from pathlib import Path
import re
import subprocess
import tempfile


def device_query(device, kind, extra=()):
    # Device inventories are temporary, never included in the retained report.
    with tempfile.TemporaryDirectory(prefix='localisync-device-query-') as directory:
        path = Path(directory) / 'result.json'
        subprocess.run(['xcrun', 'devicectl', 'device', 'info', kind,
                        '--device', device, *extra, '--json-output', str(path)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=30)
        return json.loads(path.read_text())['result']


def test_process_present(device, pid, application_url):
    processes = device_query(device, 'processes')['runningProcesses']
    process = next((row for row in processes if row['processIdentifier'] == pid), None)
    if process is None:
        return False
    if not process.get('executable', '').startswith(application_url.rstrip('/') + '/'):
        raise RuntimeError('The reported PID belongs to another application; nothing was terminated.')
    return True


def stop_test_process(device, pid, application_url):
    if not test_process_present(device, pid, application_url):
        return 'already-exited'
    result = subprocess.run(['xcrun', 'devicectl', 'device', 'process', 'terminate',
                             '--device', device, '--pid', str(pid), '--kill'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=30)
    # Natural exit can race termination. Only a verified absent process is success.
    if test_process_present(device, pid, application_url):
        raise RuntimeError('The test application did not terminate; restart acceptance stopped.')
    return 'terminated' if result.returncode == 0 else 'exited-during-stop'


def main():
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
        if record['phase'] != phase or type(record['pid']) is not int or record['pid'] <= 0:
            raise SystemExit('Invalid process restart report.')
        info = plistlib.loads((example / 'build/ios/iphoneos/Runner.app/Info.plist').read_bytes())
        apps = device_query(args.device, 'apps', ['--bundle-id', info['CFBundleIdentifier']])['apps']
        if len(apps) != 1:
            raise SystemExit('Expected exactly one installed test application.')
        record['processStop'] = stop_test_process(args.device, record['pid'], apps[0]['url'])
        results.append(record)
        print(f'{example.name}: {phase} passed', flush=True)
    if results[0]['pid'] == results[1]['pid']:
        raise SystemExit('The test did not restart the application process.')
    (args.output / f'{example.name}-restart.json').write_text(
        json.dumps({'example': example.name, 'mode': 'profile', 'phases': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
