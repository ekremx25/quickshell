"""Cold-start the full shell in a private software-rendered desktop at NOFILE1024."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ('bwrap', 'dbus-run-session', 'kwin_wayland', 'quickshell', 'wayland-info', 'python')


@unittest.skipUnless(all(shutil.which(tool) for tool in TOOLS), 'isolated desktop test tools required')
class ColdStartResourceTests(unittest.TestCase):
    def run_cold_start(self, outputs):
        scratch = ROOT/'.temp_files'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='cold-') as folder:
            temp = Path(folder)
            config = temp/'.config/quickshell'
            shutil.copytree(ROOT, config, ignore=shutil.ignore_patterns(
                '.git', '.design', '.temp_files', '__pycache__', 'demo.mp4'))
            (temp/'runtime').mkdir(mode=0o700)
            preferences = {key: ["none"] for key in ("weather", "worldclock", "markets")}
            # Define fixture preferences without relying on ignored user JSON.
            for key in ('bar', 'dock', 'osd', 'notifications', 'toast', 'workspaces'):
                preferences[key] = ['all']
            (config/'screen_config.json').write_text(json.dumps(preferences))
            shutil.copyfile(ROOT/'tests/fixtures/cold_start_probe.py', temp/'probe.py')
            command = [
                'bwrap', '--ro-bind', '/', '/', '--unshare-all', '--die-with-parent',
                '--tmpfs', '/home', '--bind', str(temp), '/home/ekrem',
                '--tmpfs', '/run', '--tmpfs', '/tmp', '--proc', '/proc',
                '--dev', '/dev', '--clearenv',
            ]
            environment = {
                'PATH': '/usr/bin:/bin', 'HOME': '/home/ekrem',
                'XDG_CONFIG_HOME': '/home/ekrem/.config',
                'XDG_CACHE_HOME': '/home/ekrem/.cache',
                'XDG_STATE_HOME': '/home/ekrem/.local/state',
                'XDG_RUNTIME_DIR': '/home/ekrem/runtime',
                'XDG_CURRENT_DESKTOP': 'KDE', 'LANG': 'C.UTF-8',
                'QT_QPA_PLATFORM': 'offscreen', 'LIBGL_ALWAYS_SOFTWARE': '1',
                'QT_QUICK_BACKEND': 'software',
            }
            for key, value in environment.items():
                command.extend(['--setenv', key, value])
            command.extend(['dbus-run-session', '--', 'python', '/home/ekrem/probe.py', str(outputs)])
            result = subprocess.run(command, capture_output=True, text=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stderr[-2000:])
            reports = [line.removeprefix('COLD_START_REPORT=') for line in result.stdout.splitlines()
                       if line.startswith('COLD_START_REPORT=')]
            self.assertEqual(len(reports), 1, result.stdout)
            return json.loads(reports[0])

    def test_probe_refuses_to_run_on_the_host_desktop(self):
        result = subprocess.run(['python', str(ROOT/'tests/fixtures/cold_start_probe.py'), '2'],
                                capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must run inside its bubblewrap PID namespace', result.stderr)

    def test_repeated_cold_starts_stay_below_descriptor_limit(self):
        for outputs in (2, 2, 4):
            with self.subTest(outputs=outputs):
                report = self.run_cold_start(outputs)
                print('Cold-start observation: ' + json.dumps(report), flush=True)
                self.assertTrue(report['loaded'], report)
                self.assertTrue(report['alive'], report)
                self.assertEqual(report['output_count'], outputs, report)
                self.assertEqual(report['nofile'], ['1024', '1024'], report)
                self.assertGreater(report['sample_count'], 100, report)
                self.assertGreater(report['observed_peak_fds'], 0, report)
                self.assertLess(report['observed_peak_fds'], 1024, report)
                for key in ('pipe_errors', 'too_many_files', 'binding_loops', 'notification_conflicts'):
                    self.assertEqual(report[key], 0, report)
