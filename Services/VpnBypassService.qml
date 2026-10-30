pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/Log.js" as Log

// Sites that open over the normal connection while a VPN is on. All the
// routing work happens in scripts/vpn_bypass.py; this keeps its last report
// and refreshes the sites' addresses (they change over time) every few hours
// and whenever a VPN connects.
Singleton {
    id: root

    readonly property string helperPath: Core.PathService.configPath("scripts/vpn_bypass.py")

    property var sites: []          // [{ domain, ipv4, ipv6, updated, direct }]
    property var legacy: []         // addresses bypassed before this list existed
    property bool vpnActive: false
    property string connectionName: ""
    property bool loaded: false
    property string errorMessage: ""
    property string lastChanged: ""
    readonly property bool busy: helper.running
    property var queue: []

    function run(args) {
        if (helper.running) {
            root.queue = root.queue.concat([args]);
            return;
        }
        helper.buffer = "";
        helper.command = ["python3", "-I", root.helperPath].concat(args);
        helper.running = true;
    }

    function status() { run(["status"]); }
    function refresh() { run(["refresh"]); }
    // "--domain=value" keeps input that starts with "-" from looking like an option.
    function addSite(domain) {
        var text = String(domain || "").trim();
        if (!text.length) return;
        root.errorMessage = "";
        run(["add", "--domain=" + text]);
    }
    function removeSite(domain) { root.errorMessage = ""; run(["remove", "--domain=" + domain]); }
    function removeLegacy(ip) { root.errorMessage = ""; run(["remove-ip", "--ip=" + ip]); }
    function clearError() { root.errorMessage = ""; }

    Process {
        id: helper
        property string buffer: ""
        stdout: SplitParser { onRead: data => helper.buffer += data + "\n" }
        stderr: SplitParser { onRead: data => Log.warn("VpnBypass", data) }
        onExited: function(exitCode) {
            var result = null;
            try {
                result = JSON.parse(helper.buffer.trim().split("\n").pop());
            } catch (e) {
                result = { ok: false, error: "Unexpected answer from the VPN bypass helper." };
            }
            if (result.ok) {
                root.sites = result.sites || [];
                root.legacy = result.legacy || [];
                root.vpnActive = result.vpnActive === true;
                root.connectionName = result.connection || "";
                root.lastChanged = result.changed || "";
                root.loaded = true;
                if (result.unresolved && result.unresolved.length)
                    Log.warn("VpnBypass", "Could not refresh: " + result.unresolved.join(", "));
            } else {
                root.errorMessage = result.error || "The site list could not be updated.";
            }
            var next = root.queue;
            if (next.length) {
                root.queue = next.slice(1);
                root.run(next[0]);
            }
        }
    }

    // Addresses behind CDNs rotate; keep the routes current.
    Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: root.sites.length > 0
        onTriggered: root.refresh()
    }

    Connections {
        target: VpnService
        function onConnectedChanged() {
            if (VpnService.connected && root.sites.length > 0) refreshAfterConnect.restart();
            else root.status();
        }
    }
    // Give the VPN's DNS a moment to come up before resolving.
    Timer { id: refreshAfterConnect; interval: 4000; onTriggered: root.refresh() }

    Component.onCompleted: status()
}
