pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core/Log.js" as Log
import "./core/VpnIdentifierLogic.js" as VpnIdentifierLogic

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
        // NetworkManager may emit several DBus events for one state change.
        // The in-flight query already observes the latest state, so do not kill
        // and restart it for every duplicate refresh event.
        if (proc.running) return;
        proc.stdoutBuf = "";
        proc.stderrBuf = "";
        proc.command = command;
        proc.running = true;
    }

    function processMessage(proc) {
        var stderrText = String(proc.stderrBuf || "").trim();
        var stdoutText = String(proc.stdoutBuf || "").trim();
        return stderrText || stdoutText;
    }

    function selectorArgs(identifier) {
        var selected = VpnIdentifierLogic.selector(identifier, root.profiles);
        return [selected.kind, selected.value];
    }

    function parseProfiles(text) {
        var lines = text.trim().length ? text.trim().split('\n') : [];
        var out = [];
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(':');
            if (parts.length >= 3 && (parts[2] === "vpn" || parts[2] === "wireguard")) {
                var autoconnect = parts.length >= 4 ? (parts[3] === "yes") : false;
                out.push({ name: parts[0], uuid: parts[1], type: parts[2], autoconnect: autoconnect });
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
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT", "connection", "show"]
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { getProfiles.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { getProfiles.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.available = true;
                root.profiles = root.parseProfiles(getProfiles.stdoutBuf);
            } else {
                root.available = false;
                Log.warn("VpnService", root.processMessage(getProfiles) || "Failed to list VPN profiles");
            }
            getProfiles.stdoutBuf = "";
            getProfiles.stderrBuf = "";
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
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { getActive.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { getActive.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                var act = root.parseActiveConnections(getActive.stdoutBuf);
                root.activeConnections = act;
                root.activeUuids = act.map(function(a) { return a.uuid; }).filter(function(u) { return !!u; });
                root.activeNames = act.map(function(a) { return a.name; }).filter(function(n) { return !!n; });
            } else {
                Log.warn("VpnService", root.processMessage(getActive) || "Failed to read active VPN connections");
            }
            getActive.stdoutBuf = "";
            getActive.stderrBuf = "";
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

    property var _vpnStepQueue: []
    property int _vpnStepIdx: 0

    function _runNextVpnStep() {
        if (_vpnStepIdx >= _vpnStepQueue.length) {
            root.isBusy = false;
            _vpnStepQueue = [];
            _vpnStepIdx = 0;
            refreshAll();
            return;
        }
        var step = _vpnStepQueue[_vpnStepIdx];
        _vpnStepIdx++;
        runVpnCommand(vpnSwitch, step);
    }

    function connect(uuidOrName) {
        if (root.isBusy) return;
        if (!uuidOrName || typeof uuidOrName !== 'string' || uuidOrName.length === 0) {
            root.errorMessage = "Invalid connection identifier";
            return;
        }

        root.isBusy = true;
        root.errorMessage = "";

        if (root.singleActive && root.activeUuids.length > 0) {
            // Build a step queue: disconnect each active VPN, then connect the new one
            var steps = [];
            for (var i = 0; i < root.activeUuids.length; i++) {
                steps.push(["nmcli", "connection", "down", "uuid", root.activeUuids[i]]);
            }
            steps.push(["nmcli", "connection", "up"].concat(selectorArgs(uuidOrName)));
            _vpnStepQueue = steps;
            _vpnStepIdx = 0;
            _runNextVpnStep();
        } else {
            runVpnCommand(vpnUp, ["nmcli", "connection", "up"].concat(selectorArgs(uuidOrName)));
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
        runVpnCommand(vpnDown, ["nmcli", "connection", "down"].concat(selectorArgs(uuidOrName)));
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
        runVpnCommand(vpnDelete, ["nmcli", "connection", "delete"].concat(selectorArgs(uuidOrName)));
    }

    Process {
        id: vpnUp
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { vpnUp.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { vpnUp.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            var message = root.processMessage(vpnUp);
            if (exitCode !== 0 && !message.toLowerCase().includes("successfully")) {
                root.errorMessage = message || "Failed to connect VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnUp.stdoutBuf = "";
            vpnUp.stderrBuf = "";
            refreshAll();
        }
    }

    Process {
        id: vpnDown
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { vpnDown.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { vpnDown.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0) {
                root.errorMessage = root.processMessage(vpnDown) || "Failed to disconnect VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnDown.stdoutBuf = "";
            vpnDown.stderrBuf = "";
            refreshAll();
        }
    }

    Process {
        id: vpnSwitch
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { vpnSwitch.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { vpnSwitch.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            var message = root.processMessage(vpnSwitch);
            vpnSwitch.stdoutBuf = "";
            vpnSwitch.stderrBuf = "";
            if (root._vpnStepQueue.length > 0) {
                // Step queue active — continue to next step
                if (exitCode !== 0) {
                    root.errorMessage = message || ("VPN step failed (exit " + exitCode + ")");
                    Log.warn("VpnService", root.errorMessage);
                }
                root._runNextVpnStep();
            } else {
                root.isBusy = false;
                if (exitCode !== 0 && root.errorMessage === "") {
                    root.errorMessage = "Failed to switch VPN";
                    Log.warn("VpnService", root.errorMessage);
                }
                refreshAll();
            }
        }
    }

    Process {
        id: vpnDelete
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { vpnDelete.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { vpnDelete.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0) {
                root.errorMessage = root.processMessage(vpnDelete) || "Failed to delete VPN";
                Log.warn("VpnService", root.errorMessage);
            }
            vpnDelete.stdoutBuf = "";
            vpnDelete.stderrBuf = "";
            refreshAll();
        }
    }

    function disconnectAllActive() {
        if (root.isBusy || root.activeUuids.length === 0) return;
        root.isBusy = true;
        var steps = [];
        for (var i = 0; i < root.activeUuids.length; i++) {
            steps.push(["nmcli", "connection", "down", "uuid", root.activeUuids[i]]);
        }
        _vpnStepQueue = steps;
        _vpnStepIdx = 0;
        _runNextVpnStep();
    }

    function setAutoconnect(uuidOrName, enabled) {
        if (root.isBusy) return;
        root.isBusy = true;
        root.errorMessage = "";
        var value = enabled ? "yes" : "no";
        runVpnCommand(setAutoconnectProcess,
            ["nmcli", "connection", "modify"].concat(selectorArgs(uuidOrName)).concat(["connection.autoconnect", value]));
    }

    Process {
        id: setAutoconnectProcess
        running: false
        property string stdoutBuf: ""
        property string stderrBuf: ""
        stdout: SplitParser { onRead: data => { setAutoconnectProcess.stdoutBuf += data + "\n"; } }
        stderr: SplitParser { onRead: data => { setAutoconnectProcess.stderrBuf += data + "\n"; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = root.processMessage(setAutoconnectProcess) || "Failed to update autoconnect";
                Log.warn("VpnService", root.errorMessage);
            }
            setAutoconnectProcess.stdoutBuf = "";
            setAutoconnectProcess.stderrBuf = "";
            refreshAll();
        }
    }
}
