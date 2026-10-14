"""The launcher prevents duplicate shells without altering resource limits."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class QuickshellLauncherTests(unittest.TestCase):
    def test_duplicate_guard_and_forwarded_arguments(self):
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='launch-') as folder:
            temp = Path(folder)
            executable = temp / 'quickshell'
            executable.write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n')
            executable.chmod(0o755)
            env = dict(os.environ, PATH=str(temp) + ':' + os.environ['PATH'])
            result = subprocess.run(['bash', str(ROOT/'scripts/start-quickshell.sh'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['--no-duplicate', '--path',
                             str(ROOT/'shell.qml'), '--no-color'])
