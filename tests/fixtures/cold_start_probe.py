"""Runs only inside the disposable bubblewrap/private-D-Bus test environment."""
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

HOME = Path(os.environ['HOME'])


def limit_descriptors():
    resource.setrlimit(resource.RLIMIT_NOFILE, (1024, 1024))


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=4)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def main():
    if Path('/proc/1/comm').read_text().strip() != 'bwrap':
        raise RuntimeError('Cold-start probe must run inside its bubblewrap PID namespace')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
               LIBGL_ALWAYS_SOFTWARE='1', QT_QUICK_BACKEND='software')
    shell = None
    with open(HOME/'compositor.log', 'w') as compositor_log:
        compositor = subprocess.Popen([
            'kwin_wayland', '--virtual', '--socket', 'wayland-test',
            '--width', '1920', '--height', '1080', '--output-count', sys.argv[1],
            '--no-lockscreen', '--no-global-shortcuts', '--no-kactivities',
        ], env=env, stdout=compositor_log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 12
            socket = Path(env['XDG_RUNTIME_DIR'])/'wayland-test'
            while not socket.exists():
                if compositor.poll() is not None:
                    raise RuntimeError('Virtual compositor exited before creating its socket')
                if time.monotonic() > deadline:
                    raise RuntimeError('Virtual compositor socket timeout')
                time.sleep(0.01)
            env.update(QT_QPA_PLATFORM='wayland', WAYLAND_DISPLAY='wayland-test')
            info = subprocess.run(['wayland-info'], env=env, capture_output=True,
                                  text=True, timeout=8, check=True)
            output_count = info.stdout.count("interface: 'wl_output'")
            with open(HOME/'shell.log', 'w') as shell_log:
                shell = subprocess.Popen([
                    'quickshell', '--path', str(HOME/'.config/quickshell'), '--no-color',
                ], env=env, stdout=shell_log, stderr=subprocess.STDOUT,
                    preexec_fn=limit_descriptors)
                started = time.monotonic()
                samples = []
                # A measured startup/settling window, not a synchronization sleep.
                while time.monotonic() - started < 12 and shell.poll() is None:
                    try:
                        samples.append(len(list(Path(f'/proc/{shell.pid}/fd').iterdir())))
                    except FileNotFoundError:
                        break
                    time.sleep(0.002)
                alive = shell.poll() is None
                limits = Path(f'/proc/{shell.pid}/limits').read_text() if alive else ''
                nofile = next((line.split()[3:5] for line in limits.splitlines()
                               if line.startswith('Max open files')), [])
                text = (HOME/'shell.log').read_text()
                report = {
                    'loaded': 'Configuration Loaded' in text,
                    'ui_results': [line for line in text.splitlines() if 'SETTINGS_UI_' in line],
                    'qml_reference_errors': text.count('ReferenceError') + text.count('TypeError'),
                    'alive': alive,
                    'output_count': output_count,
                    'sample_count': len(samples),
                    'observed_peak_fds': max(samples, default=0),
                    'final_fds': samples[-1] if samples else 0,
                    'nofile': nofile,
                    'pipe_errors': text.count('Cannot create pipe'),
                    'too_many_files': text.count('Too many open files'),
                    'binding_loops': text.count('Binding loop'),
                    'notification_conflicts': text.count('Could not register notification server'),
                    'network_unavailable': 'Could not resolve host' in text,
                    'pipewire_unavailable': 'Failed to connect pipewire context' in text,
                }
                print('COLD_START_REPORT=' + json.dumps(report), flush=True)
        finally:
            stop(shell)
            stop(compositor)


if __name__ == '__main__':
    main()
