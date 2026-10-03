"""Choose an installed iPhone simulator explicitly, without assuming a device name."""
import json
import os
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN', 'flutter')
data = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
devices = [d for group in data['devices'].values() for d in group if d['isAvailable'] and d['name'].startswith('iPhone')]
if not devices:
    raise SystemExit('No supported iPhone simulator is installed.')
device = next((d for d in devices if d['state'] == 'Booted'), devices[0])
booted_here = device['state'] != 'Booted'
try:
    if booted_here:
        subprocess.run(['xcrun','simctl','boot',device['udid']], check=True)
    subprocess.run(['xcrun','simctl','bootstatus',device['udid'],'-b'],check=True)
    subprocess.run([sys.executable, str(root / 'tool/native_acceptance.py'), '--device', device['udid']], check=True)
finally:
    if booted_here:
        subprocess.run(['xcrun','simctl','shutdown',device['udid']],check=True)
