"""Run both iOS examples with log capture established before app launch."""
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import tempfile
import time
from urllib.parse import urlparse

from process_output import run_logged


def completed_tests(output):
    """Accept one exact marker from the successful integration driver callback."""
    marker = 'LOCALISYNC_IOS_ACCEPTANCE={"passed":1}'
    return sum(line.strip() == marker for line in output.splitlines())


def run_example(root, flutter, device, example, output):
    started = time.monotonic()
    stem = f'native-{example}-platform_test'
    app = root / 'examples' / example
    result = None
    passed = 0
    with tempfile.TemporaryDirectory(prefix='localisync-ios-') as temporary:
        service_file = Path(temporary) / 'service-uri'
        with (output / f'{stem}-launch.log').open('w') as launch_log:
            # `flutter run` listens before the build; `flutter test`/`drive`
            # launching directly have the log-discovery race in issue 181771.
            process = subprocess.Popen([
                flutter, 'run', '--machine', '--verbose', '--start-paused', '--target',
                'integration_test/platform_test.dart', '-d', device,
                '--vmservice-out-file', str(service_file),
            ], cwd=app, stdin=subprocess.DEVNULL, stdout=launch_log,
                stderr=subprocess.STDOUT, start_new_session=True)
            try:
                deadline = time.monotonic() + 1200
                while not service_file.exists():
                    if process.poll() is not None:
                        raise RuntimeError('Simulator application exited before test connection.')
                    if time.monotonic() >= deadline:
                        raise TimeoutError('Simulator application did not expose its test connection.')
                    time.sleep(0.2)
                uri = service_file.read_text().strip()
                parsed = urlparse(uri)
                if parsed.scheme not in ('ws', 'http') or parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
                    raise RuntimeError('Expected a loopback simulator test connection.')
                result = run_logged([
                    flutter, 'drive', '--driver', 'test_driver/platform_driver.dart',
                    '--use-existing-app', uri, '-d', device,
                ], app, output / f'{stem}.log', 300)
                passed = completed_tests(result.stdout)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=15)
                success = result is not None and result.returncode == 0 and passed == 1
                (output / f'{stem}.json').write_text(json.dumps({
                    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                    'os': platform.platform(), 'target': 'integration_test/platform_test.dart',
                    'example': example, 'device': device, 'runner': 'flutter run + drive existing app',
                    'seconds': time.monotonic() - started, 'passed': passed,
                    'exitCode': result.returncode if result is not None else None,
                    'success': success, 'skipped': 0,
                }, indent=2) + '\n')
    if not success:
        raise RuntimeError(f'iOS acceptance failed or ran zero tests: {example}')


def main():
    root = Path(__file__).resolve().parents[1]
    flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
    if not flutter:
        raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
    data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
    devices = [(runtime, d) for runtime, group in data['devices'].items() for d in group
               if d['isAvailable'] and d['name'].startswith('iPhone')]
    if not devices:
        raise SystemExit('No supported iPhone simulator is installed.')
    runtime, template = devices[0]
    device = subprocess.check_output([
        'xcrun', 'simctl', 'create', 'Localisync acceptance',
        template['deviceTypeIdentifier'], runtime,
    ], text=True).strip()
    output = (root if (root / 'test/sdk-protocol').is_dir() else root.parents[1]) / '.local/flutter-validation'
    output.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'boot', device], check=True)
        subprocess.run(['xcrun', 'simctl', 'bootstatus', device, '-b'], check=True)
        for example in ['basic', 'gen_l10n']:
            run_example(root, flutter, device, example, output)
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], check=False)
        subprocess.run(['xcrun', 'simctl', 'delete', device], check=True)


if __name__ == '__main__':
    main()
