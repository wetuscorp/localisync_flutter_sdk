"""Rebuild runtime license inventories and query resolved Pub dependencies in OSV.

Run after flutter pub get. No credentials or application configuration are read.
The network audit reports known advisories, not a proof of vulnerability absence.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urljoin, unquote, urlparse
from urllib.request import Request, urlopen

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
parser.add_argument('--audit', action='store_true')
args = parser.parse_args()
flutter = os.environ.get('LOCALISYNC_FLUTTER_BIN') or shutil.which('flutter')
if not flutter:
    raise SystemExit('Set LOCALISYNC_FLUTTER_BIN or put Flutter on PATH.')
graph = json.loads(subprocess.check_output([flutter, 'pub', 'deps', '--json'], cwd=root))
packages = {entry['name']: entry for entry in graph['packages']}
config_file = root / '.dart_tool/package_config.json'
config = json.loads(config_file.read_text())
paths = {entry['name']: Path(unquote(urlparse(urljoin(config_file.as_uri(), entry['rootUri'])).path))
         for entry in config['packages']}
if os.name == 'nt':
    paths = {name: Path(str(path).lstrip('/\\')) for name, path in paths.items()}

for package in ['localisync_sdk', 'localisync_generator']:
    seen = set()
    def visit(name):
        if name in seen:
            return
        seen.add(name)
        item = packages[name]
        for child in item.get('directDependencies', item['dependencies']):
            visit(child)
    visit(package)
    inventory, notices = [], []
    for name in sorted(seen):
        item = packages[name]
        if item['source'] == 'root':
            continue
        files = [path for path in paths[name].iterdir()
                 if path.is_file() and path.name.upper().split('.')[0] in ['LICENSE', 'COPYING', 'NOTICE']]
        if not files:
            raise SystemExit(f'Missing license for {name}.')
        inventory.append({key: item[key] for key in ['name', 'version', 'source']})
        for path in sorted(files):
            notices.append(f'{name} {item["version"]} — {path.name}\n\n{path.read_text()}\n')
    directory = (root / ('tool/generator' if package == 'localisync_generator' else 'packages/localisync_sdk')) / 'licenses'
    directory.mkdir(exist_ok=True)
    for name, content in {
        'inventory.json': json.dumps(inventory, indent=2) + '\n',
        'DEPENDENCIES.txt': '\n'.join(line.rstrip() for line in '\n\n'.join(notices).splitlines()).rstrip() + '\n',
    }.items():
        destination = directory / name
        if args.check:
            if not destination.exists() or destination.read_text() != content:
                raise SystemExit(f'Stale license inventory: {destination.relative_to(root)}')
        else:
            destination.write_text(content)
    print(f'{package}: {len(inventory)} runtime dependency notices checked.')

if args.audit:
    hosted = sorted((p for p in packages.values() if p['source'] == 'hosted'), key=lambda p: p['name'])
    body = json.dumps({'queries': [{'package': {'ecosystem': 'Pub', 'name': p['name']},
                                    'version': p['version']} for p in hosted]}).encode()
    request = Request('https://api.osv.dev/v1/querybatch', data=body,
                      headers={'Content-Type': 'application/json'}, method='POST')
    with urlopen(request, timeout=60) as response:
        results = json.load(response)['results']
    if len(results) != len(hosted):
        raise SystemExit('The advisory response was incomplete.')
    findings = [{'name': package['name'], 'version': package['version'], 'advisories': result['vulns']}
                for package, result in zip(hosted, results) if result.get('vulns')]
    print(json.dumps({'checkedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      'source': 'OSV Pub ecosystem', 'packages': len(hosted), 'findings': findings}, indent=2))
    if findings:
        raise SystemExit(1)
