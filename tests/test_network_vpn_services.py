"""Exercise Network and VPN services with isolated fake NetworkManager commands."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NetworkVpnServiceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_active_selection_details_and_monitor_reconnect(self):
        with tempfile.TemporaryDirectory(prefix="qs-network-vpn-") as directory:
            temp = Path(directory)
            binaries = temp / "bin"
            binaries.mkdir()
            network_monitor_log = temp / "network-monitor.log"
            dbus_monitor_log = temp / "dbus-monitor.log"
            nmcli_args_log = temp / "nmcli-args.log"

            nmcli = binaries / "nmcli"
            nmcli.write_text('''#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$NMCLI_ARGS_LOG"
if [[ " $* " == *" monitor "* ]]; then
    printf 'monitor-start\\n' >> "$NETWORK_MONITOR_LOG"
    printf 'connection changed\\n'
    exit 1
fi
if [[ " $* " == *" NAME,TYPE "* && " $* " == *" --active "* ]]; then
    printf '%s\\n' 'Tunnel\\: Primary:vpn' 'Office\\: LAN:802-3-ethernet'
    exit 0
fi
if [[ " $* " == *" NAME,UUID,TYPE,DEVICE,STATE "* && " $* " == *" --active "* ]]; then
    printf '%s\\n' 'Work\\: VPN:11111111-1111-1111-1111-111111111111:vpn:tun0:activated' \\
                    'WireGuard:22222222-2222-2222-2222-222222222222:wireguard:wg0:activated'
    exit 0
fi
if [[ " $* " == *" NAME,UUID,TYPE,AUTOCONNECT "* ]]; then
    printf '%s\\n' 'Work\\: VPN:11111111-1111-1111-1111-111111111111:vpn:yes' \\
                    'WireGuard:22222222-2222-2222-2222-222222222222:wireguard:no'
    exit 0
fi
exit 0
''')
            nmcli.chmod(0o755)

            gdbus = binaries / "gdbus"
            gdbus.write_text('''#!/bin/bash
set -eu
printf 'monitor-start\\n' >> "$DBUS_MONITOR_LOG"
printf 'PropertiesChanged\\n'
exit 1
''')
            gdbus.chmod(0o755)

            config = temp / "config/quickshell"
            config.mkdir(parents=True)
            (config / "Services").symlink_to(ROOT / "Services")
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            source = '''import QtQuick
import Quickshell
import "SERVICES"
import "__SYSTEM_URI__"
ShellRoot {
    NetworkService { id: networkSettings; active: false }
    // Force lazy singletons to initialize before the verification timer fires.
    readonly property bool initialNetworkState: Network.connected
    readonly property bool initialVpnState: VpnService.connected
    function check(condition, message) { if (!condition) throw new Error(message); }
    Timer {
        interval: 2600; running: true
        onTriggered: {
            try {
                var directSelection = Network.selectActiveConnection("Tunnel\\\\: Primary:vpn\\nOffice\\\\: LAN:802-3-ethernet\\n");
                check(directSelection && directSelection.name === "Office: LAN", "direct network selection");
                check(Network.connected, "network connected: " + Network.activeConnection + "/" + Network.activeConnectionType);
                check(Network.activeConnection === "Office: LAN", "physical active connection selected");
                check(Network.activeConnectionType === "ETHERNET", "physical connection type");

                networkSettings.parseWifiList("Strong:87:WPA2:▂▄▆█:yes\\nMedium:72:WPA2:▂▄▆_:no\\nWeak:27:WPA2:▂___:no\\n");
                check(networkSettings.wifiList.length === 3, "wifi list parsed");
                check(networkSettings.wifiList[0].barLevel === 4, "four-bar signal level");
                check(networkSettings.wifiList[1].barLevel === 3, "three-bar signal level");
                check(networkSettings.wifiList[2].barLevel === 1, "one-bar signal level");

                check(VpnService.profiles.length === 2, "vpn profiles loaded");
                check(VpnService.profiles[0].name === "Work: VPN", "escaped vpn profile name");
                check(VpnService.activeConnections.length === 2, "all active vpn connections loaded");
                check(VpnService.activeUuid === "11111111-1111-1111-1111-111111111111", "primary active uuid");
                var details = VpnService.getConnectionDetails(VpnService.activeUuid);
                check(details.name === "Work: VPN", "connection details name");
                check(details.device === "tun0" && details.state === "activated", "connection details state");
                check(details.timestamp > 0, "connection details timestamp");
                check(Date.now() - details.timestamp >= 1500, "connection timestamp preserved across refreshes");
                check(VpnService.getConnectionDuration(VpnService.activeUuid).length > 0, "connection duration");
                console.log("NETWORK_VPN_PASS");
            } catch (error) {
                console.error("NETWORK_VPN_FAIL " + error);
            }
            Qt.quit();
        }
    }
}'''.replace("SERVICES", (ROOT / "Services").as_uri()) \
                 .replace("__SYSTEM_URI__", (ROOT / "Modules/bar/System").as_uri())
            entry = temp / "shell.qml"
            entry.write_text(source)
            env = dict(os.environ,
                       PATH=str(binaries) + ":/usr/bin:/bin",
                       NETWORK_MONITOR_LOG=str(network_monitor_log),
                       DBUS_MONITOR_LOG=str(dbus_monitor_log),
                       NMCLI_ARGS_LOG=str(nmcli_args_log),
                       QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_CONFIG_HOME=str(temp / "config"), XDG_RUNTIME_DIR=str(runtime),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_STATE_HOME=str(temp / "state"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("NETWORK_VPN_PASS", output + "\nnmcli calls:\n" + (nmcli_args_log.read_text() if nmcli_args_log.exists() else "<none>"))
            self.assertNotIn("NETWORK_VPN_FAIL", output)
            self.assertGreaterEqual(len(network_monitor_log.read_text().splitlines()), 2)
            self.assertGreaterEqual(len(dbus_monitor_log.read_text().splitlines()), 2)


if __name__ == "__main__":
    unittest.main()
