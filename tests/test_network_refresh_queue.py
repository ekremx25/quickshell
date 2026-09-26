"""Control query completion and monitor lifetime with explicit fixture handshakes."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FAKE = r'''
import os, pathlib, sys, time
root = pathlib.Path(os.environ['FIXTURE'])
mode = os.environ['MODE']
name = pathlib.Path(sys.argv[0]).name

def wait(predicate):
    deadline = time.monotonic() + 8
    while not predicate():
        if time.monotonic() > deadline: raise RuntimeError('fixture handshake timeout')
        time.sleep(0.005)

def mark(name): (root / name).touch()
def count(key):
    p = root / (key + '.count')
    n = int(p.read_text()) + 1 if p.exists() else 1
    p.write_text(str(n))
    return n

if name == 'controller':
    wait(lambda: all((root / (k + '.ready')).exists() for k in ['network','profiles','active','nm-monitor','dbus-monitor']))
    print('READY', flush=True)
    if sys.stdin.readline().strip() != 'release': raise RuntimeError('missing release acknowledgement')
    mark('release')
    wait(lambda: (root / 'finish').exists())
    sys.exit(0)
if name == 'gdbus' or sys.argv[1:] == ['monitor']:
    key = 'dbus-monitor' if name == 'gdbus' else 'nm-monitor'
    n = count(key)
    mark(key + '.ready')
    if mode == 'reconnect' and n == 1:
        wait(lambda: (root / 'release').exists())
        sys.exit(1)
    # No stdout, including after reconnect: only onStarted can refresh snapshots.
    wait(lambda: (root / 'finish').exists())
    sys.exit(0)
args = ' '.join(sys.argv[1:])
key = 'profiles' if 'AUTOCONNECT' in args else 'active' if 'UUID' in args else 'network'
n = count(key)
if n > 2: raise RuntimeError('refresh burst was not coalesced: ' + key)
mark(key + '.ready')
if mode != 'reconnect' and n == 1:
    wait(lambda: (root / 'release').exists())
if mode == 'failure' and n == 1: sys.exit(1)
label = 'New' if n == 2 else 'Old'
if key == 'network': print(label + ':802-3-ethernet')
elif key == 'profiles': print(label + ':11111111-1111-1111-1111-111111111111:vpn:yes')
else: print(label + ':11111111-1111-1111-1111-111111111111:vpn:tun0:activated')
'''


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class NetworkRefreshQueueTests(unittest.TestCase):
    def test_silent_reconnect_takes_new_snapshots(self):
        self.run_scenario('reconnect')

    def test_refresh_burst_queues_one_followup_per_query(self):
        self.run_scenario('queue')

    def test_failed_query_still_drains_pending_refresh(self):
        self.run_scenario('failure')

    def run_scenario(self, mode):
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='nq-') as directory:
            temp = Path(directory)
            binaries = temp / 'bin'
            binaries.mkdir()
            for name in ('nmcli', 'gdbus', 'controller'):
                path = binaries / name
                path.write_text('#!' + sys.executable + '\n' + FAKE)
                path.chmod(0o700)
            runtime = temp / 'r'
            runtime.mkdir(mode=0o700)
            source = '''import QtQuick
import Quickshell
import Quickshell.Io
import "SERVICES"
ShellRoot {
    id: test
    property bool networkState: Network.connected
    property bool vpnState: VpnService.connected
    property bool ready: false
    property bool released: false
    property bool done: false
    function advance() {
        if (done || !ready) return;
        if (!released) {
            if ("MODE" === "reconnect" && (Network.activeConnection !== "Old" || VpnService.activeName !== "Old" || VpnService.profiles.length !== 1 || VpnService.profiles[0].name !== "Old")) return;
            released = true;
            if ("MODE" !== "reconnect") {
                for (var i = 0; i < 5; i++) { Network.refresh(); VpnService.refreshAll(); }
            }
            controller.write("release\\n");
        }
        if (Network.activeConnection === "New" && VpnService.activeName === "New" && VpnService.profiles.length === 1 && VpnService.profiles[0].name === "New") {
            done = true;
            console.log("REFRESH_PASS");
            Qt.quit();
        }
    }
    Connections { target: Network; function onActiveConnectionChanged() { Qt.callLater(test.advance); } }
    Connections { target: VpnService; function onConnectionInfoUpdated() { Qt.callLater(test.advance); } function onProfilesChanged() { Qt.callLater(test.advance); } }
    Process {
        id: controller
        command: ["controller"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => { if (line === "READY") { test.ready = true; Qt.callLater(test.advance); } } }
    }
    Timer { interval: 7000; running: true; onTriggered: { console.error("REFRESH_TIMEOUT"); Qt.quit(); } }
}'''.replace('SERVICES', (ROOT / 'Services').as_uri()).replace('MODE', mode)
            entry = temp / 'shell.qml'
            entry.write_text(source)
            env = dict(os.environ, PATH=str(binaries) + ':' + os.environ['PATH'], FIXTURE=str(temp), MODE=mode,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=str(runtime),
                       XDG_CONFIG_HOME=str(temp / 'config'), XDG_CACHE_HOME=str(temp / 'cache'), XDG_STATE_HOME=str(temp / 'state'))
            env.pop('WAYLAND_DISPLAY', None)
            try:
                result = subprocess.run(['quickshell', '-p', str(entry), '--no-color'], env=env,
                                        capture_output=True, text=True, timeout=12)
            finally:
                (temp / 'finish').touch()
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('REFRESH_PASS', output)
            self.assertNotIn('REFRESH_TIMEOUT', output)
            for key in ('network', 'profiles', 'active'):
                self.assertEqual((temp / (key + '.count')).read_text(), '2', key + '\n' + output)
            for key in ('nm-monitor', 'dbus-monitor'):
                self.assertEqual((temp / (key + '.count')).read_text(), '2' if mode == 'reconnect' else '1')


if __name__ == '__main__':
    unittest.main()
