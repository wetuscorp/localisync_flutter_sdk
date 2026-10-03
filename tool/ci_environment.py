"""Discover installed CI browsers without changing developer machine preferences."""
import os
from pathlib import Path
import platform
import shutil

candidates = [
    shutil.which('google-chrome'), shutil.which('google-chrome-stable'),
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    str(Path(os.environ.get('PROGRAMFILES', 'C:/Program Files')) / 'Google/Chrome/Application/chrome.exe'),
    str(Path(os.environ.get('PROGRAMFILES(X86)', 'C:/Program Files (x86)')) / 'Google/Chrome/Application/chrome.exe'),
]
chrome = next((path for path in candidates if path and Path(path).is_file()), None)
if not chrome:
    raise SystemExit('A real Chrome executable is required for Flutter browser acceptance.')
print(f'Platform: {platform.platform()}\nChrome: {chrome}')
if os.environ.get('GITHUB_ENV'):
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
        output.write(f'CHROME_EXECUTABLE={chrome}\n')
