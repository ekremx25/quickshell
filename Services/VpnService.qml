pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core/Log.js" as Log

Singleton {
    id: root

    property bool available: true
    property bool isBusy: false
    property string errorMessage: ""

    property var profiles: []

    property bool singleActive: false

    property var activeConnections: []
    property var activeUuids: []
    property var activeNames: []
    property string activeUuid: activeUuids.length > 0 ? activeUuids[0] : ""
    property string activeName: activeNames.length > 0 ? activeNames[0] : ""
    property string activeDevice: activeConnections.length > 0 ? (activeConnections[0].device || "") : ""
    property string activeState: activeConnections.length > 0 ? (activeConnections[0].state || "") : ""
    property bool connected: activeUuids.length > 0

    property var connectionDetails: ({})

    signal connectionInfoUpdated()

    Component.onCompleted: initialize()

    Component.onDestruction: {
        nmMonitor.running = false;
    }

    function initialize() {
        nmMonitor.running = true;
        refreshAll();
    }

    function refreshAll() {
        listProfiles();
        refreshActive();
    }

    function runVpnCommand(proc, command) {
        proc.buf = "";
        proc.command = command;
        proc.running = false;
        proc.running = true;
    }

    function parseProfiles(text) {
        var lines = text.trim().length ? text.trim().split('\n') : [];
        var out = [];
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(':');
            if (parts.length >= 3 && (parts[2] === "vpn" || parts[2] === "wireguard")) {
                var autoconnect = parts.length >= 5 ? (parts[4] === "yes") : false;
                out.push({ name: parts[0], uuid: parts[1], type: parts[2], serviceType: parts[3] || "", autoconnect: autoconnect });
            }
        }
        return out;
    }

    function parseActiveConnections(text) {
        var lines = text.trim().length ? text.trim().split('\n') : [];
        var act = [];
        var now = Date.now();
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(':');
            if (parts.length >= 5 && (parts[2] === "vpn" || parts[2] === "wireguard")) {
                var uuid = parts[1];
                var existing = null;
                for (var j = 0; j < root.activeConnections.length; j++) {
                    if (root.activeConnections[j].uuid === uuid) { existing = root.activeConnections[j]; break; }
                }
                var timestamp = existing && existing.timestamp ? existing.timestamp : now;
                act.push({
                    name: parts[0],
                    uuid: uuid,
                    device: parts[3],
                    state: parts[4],
                    timestamp: timestamp
                });
            }
        }
        return act;
    }

    // Watch for NetworkManager changes via dbus
    Process {
        id: nmMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.NetworkManager"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.indexOf("ActiveConnection") !== -1 || line.indexOf("PropertiesChanged") !== -1 || line.indexOf("StateChanged") !== -1) {
                    refreshAll();
                }
            }
        }
    }

    function listProfiles() {
        runVpnCommand(getProfiles, getProfiles.command);
    }

    Process {
        id: getProfiles
        command: ["bash", "-lc", "nmcli -t -f NAME,UUID,TYPE connection show | while IFS=: read -r name uuid type; do case \"$type\" in vpn) autoconnect=$(nmcli -g connection.autoconnect connection show uuid \"$uuid\" 2>/dev/null || echo 'no'); echo \"$name:$uuid:$type::$autoconnect\" ;; wireguard) autoconnect=$(nmcli -g connection.autoconnect connection show uuid \"$uuid\" 2>/dev/null || echo 'no'); echo \"$name:$uuid:$type::$autoconnect\" ;; *) : ;; esac; done"]
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { getProfiles.buf += data + "\n"; } }
        onExited: {
            root.profiles = root.parseProfiles(getProfiles.buf);
            getProfiles.buf = "";
        }
    }

    function refreshActive() {
        runVpnCommand(getActive, getActive.command);
    }

    function getConnectionDetails(uuid) {
        return root.connectionDetails[uuid] || {};
    }

    function getConnectionDuration(uuid) {
        var details = root.connectionDetails[uuid];
        if (!details || !details.timestamp) return "";
        var now = Date.now();
        var elapsed = now - details.timestamp;
        var seconds = Math.floor(elapsed / 1000);
        var minutes = Math.floor(seconds / 60);
        var hours = Math.floor(minutes / 60);
        var days = Math.floor(hours / 24);

        if (days > 0) return days + "d " + (hours % 24) + "h";
        if (hours > 0) return hours + "h " + (minutes % 60) + "m";
        if (minutes > 0) return minutes + "m " + (seconds % 60) + "s";
        return seconds + "s";
    }

    Process {
        id: getActive
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { getActive.buf += data + "\n"; } }
        onExited: {
            var act = root.parseActiveConnections(getActive.buf);
            root.activeConnections = act;
            root.activeUuids = act.map(function(a) { return a.uuid; }).filter(function(u) { return !!u; });
            root.activeNames = act.map(function(a) { return a.name; }).filter(function(n) { return !!n; });
            getActive.buf = "";
        }
    }

    Timer {
        id: durationUpdateTimer
        interval: 1000
        running: root.connected
        repeat: true
        onTriggered: {
            root.connectionInfoUpdated();
        }
    }

    function isActiveUuid(uuid) {
        return root.activeUuids && root.activeUuids.indexOf(uuid) !== -1;
    }

    function _looksLikeUuid(s) {
        return s && s.indexOf('-') !== -1 && s.length >= 8;
    }

    function _escapeShellArg(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function connect(uuidOrName) {
        if (root.isBusy) return;
        if (!uuidOrName || typeof uuidOrName !== 'string' || uuidOrName.length === 0) {
            root.errorMessage = "Invalid connection identifier";
            return;
        }

        root.isBusy = true;
        root.errorMessage = "";

        if (root.singleActive) {
            var escaped = _escapeShellArg(uuidOrName);
            var upCmd = _looksLikeUuid(uuidOrName) ? "nmcli connection up uuid " + escaped : "nmcli connection up id " + escaped;
            var script = "set -e\n" +
                         "nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2 ~ /^(vpn|wireguard)$/ {print $1}' | while read u; do [ -n \"$u\" ] && nmcli connection down uuid \"$u\" || true; done\n" +
                         upCmd + "\n";
            runVpnCommand(vpnSwitch, ["bash", "-lc", script]);
        } else {
            runVpnCommand(vpnUp, _looksLikeUuid(uuidOrName)
                ? ["nmcli", "connection", "up", "uuid", uuidOrName]
                : ["nmcli", "connection", "up", "id", uuidOrName]);
        }
    }

    function disconnect(uuidOrName) {
        if (root.isBusy) return;
        if (!uuidOrName || typeof uuidOrName !== 'string' || uuidOrName.length === 0) {
            root.errorMessage = "Invalid connection identifier";
            return;
        }

        root.isBusy = true;
        root.errorMessage = "";
        runVpnCommand(vpnDown, _looksLikeUuid(uuidOrName)
            ? ["nmcli", "connection", "down", "uuid", uuidOrName]
            : ["nmcli", "connection", "down", "id", uuidOrName]);
    }

    function toggle(uuid) {
        if (uuid) {
            if (isActiveUuid(uuid)) disconnect(uuid);
            else connect(uuid);
            return;
        }
        if (root.profiles.length > 0) {
            connect(root.profiles[0].uuid);
        }
    }

    function deleteConnection(uuidOrName) {
        if (root.isBusy) return;
        root.isBusy = true;
        root.errorMessage = "";
        runVpnCommand(vpnDelete, _looksLikeUuid(uuidOrName)
            ? ["nmcli", "connection", "delete", "uuid", uuidOrName]
            : ["nmcli", "connection", "delete", "id", uuidOrName]);
    }

    Process {
        id: vpnUp
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { vpnUp.buf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0 && !vpnUp.buf.toLowerCase().includes("successfully")) {
                root.errorMessage = vpnUp.buf.trim() || "Failed to connect VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnUp.buf = "";
            refreshAll();
        }
    }

    Process {
        id: vpnDown
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { vpnDown.buf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0) {
                root.errorMessage = vpnDown.buf.trim() || "Failed to disconnect VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnDown.buf = "";
            refreshAll();
        }
    }

    Process {
        id: vpnSwitch
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { vpnSwitch.buf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to switch VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnSwitch.buf = "";
            refreshAll();
        }
    }

    Process {
        id: vpnDelete
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { vpnDelete.buf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0) {
                root.errorMessage = vpnDelete.buf.trim() || "Failed to delete VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnDelete.buf = "";
            refreshAll();
        }
    }

    function disconnectAllActive() {
        if (root.isBusy) return;
        root.isBusy = true;
        var script = "nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2 ~ /^(vpn|wireguard)$/ {print $1}' | while read u; do [ -n \"$u\" ] && nmcli connection down uuid \"$u\" || true; done";
        runVpnCommand(vpnSwitch, ["bash", "-lc", script]);
    }

    function setAutoconnect(uuidOrName, enabled) {
        if (root.isBusy) return;
        root.isBusy = true;
        root.errorMessage = "";
        var value = enabled ? "yes" : "no";
        runVpnCommand(setAutoconnectProcess, _looksLikeUuid(uuidOrName)
            ? ["nmcli", "connection", "modify", "uuid", uuidOrName, "connection.autoconnect", value]
            : ["nmcli", "connection", "modify", "id", uuidOrName, "connection.autoconnect", value]);
    }

    Process {
        id: setAutoconnectProcess
        running: false
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to update autoconnect";
                Log.warn("VpnService", root.errorMessage);
            }
            refreshAll();
        }
    }
}
