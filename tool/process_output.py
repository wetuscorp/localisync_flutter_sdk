"""Stream acceptance output and bound a child process tree on every CI host."""
import os
from pathlib import Path
import signal
import subprocess
import threading


def run_logged(command, cwd, log_path: Path, timeout: int):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(f'Running {command} in {cwd} (timeout {timeout}s)', flush=True)
    options = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else {'start_new_session': True}
    with log_path.open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=cwd, text=True, encoding='utf-8', errors='replace',
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **options)
        lines = []

        def stream():
            for line in process.stdout:
                lines.append(line)
                log.write(line)
                log.flush()
                print(line, end='', flush=True)

        reader = threading.Thread(target=stream, daemon=True)
        reader.start()
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            print('Acceptance command exceeded its deadline; terminating its process tree.', flush=True)
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], check=False)
            else:
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=30)
        reader.join(timeout=30)
        if reader.is_alive():
            raise RuntimeError('Acceptance process left its output stream open.')
        return subprocess.CompletedProcess(command, 124 if timed_out else process.returncode, ''.join(lines))
