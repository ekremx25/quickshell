pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core/NmcliTerseParser.js" as NmcliTerseParser

Singleton {
    id: root

    property bool connected: activeConnectionType !== ""
    property string activeConnection: "Disconnected"
    property string activeConnectionType: ""

    property bool _destroying: false
    property bool _monitorStartedOnce: false
    property bool _applyingRefresh: false
    property bool _refreshPending: false
    property int monitorRetryDelay: 1000
    readonly property int monitorRetryMaxDelay: 30000

    Component.onCompleted: {
        refresh();
        startMonitor();
    }

    Component.onDestruction: {
        _destroying = true;
        monitorReconnectTimer.stop();
        monitorStableTimer.stop();
        nmMonitorProcess.running = false;
    }

    function refresh() {
        if (_destroying) return;
        if (refreshProcess.running || _applyingRefresh) { _refreshPending = true; return; }
        refreshProcess.running = true;
    }

    function getConnectionType(nmcliType) {
        var value = String(nmcliType || "");
        if (value.indexOf("ethernet") !== -1) return "ETHERNET";
        if (value.indexOf("wireless") !== -1 || value === "wifi") return "WIFI";
        return "";
    }

    function selectActiveConnection(text) {
        var records = NmcliTerseParser.parseLines(text);
        for (var i = 0; i < records.length; i++) {
            var fields = records[i];
            if (fields.length < 2) continue;
            var type = getConnectionType(fields[1]);
            if (type !== "") return { name: fields[0], type: type };
        }
        return null;
    }

    function applyActiveConnection(connection) {
        if (!connection) {
            activeConnectionType = "";
            activeConnection = "Disconnected";
            return;
        }
        activeConnectionType = connection.type;
        activeConnection = connection.name;
    }

    function startMonitor() {
        if (!_destroying && !nmMonitorProcess.running) nmMonitorProcess.running = true;
    }

    Process {
        id: refreshProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"]
        property string stdoutBuffer: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { refreshProcess.stdoutBuffer += data; }
        }
        onRunningChanged: {
            if (running) stdoutBuffer = "";
        }
        onExited: exitCode => {
            root._applyingRefresh = true;
            if (exitCode === 0) root.applyActiveConnection(root.selectActiveConnection(stdoutBuffer));
            stdoutBuffer = "";
            root._applyingRefresh = false;
            if (root._refreshPending) {
                root._refreshPending = false;
                root.refresh();
            }
        }
    }

    Process {
        id: nmMonitorProcess
        running: false
        command: ["nmcli", "monitor"]
        onStarted: {
            // Startup already takes a snapshot; a later monitor may be silent.
            if (root._monitorStartedOnce) root.refresh();
            root._monitorStartedOnce = true;
        }
        stdout: SplitParser {
            onRead: data => {
                if (String(data || "").trim() === "") return;
                root.monitorRetryDelay = 1000;
                root.refresh();
            }
        }
        onRunningChanged: {
            if (running) monitorStableTimer.restart();
            else monitorStableTimer.stop();
        }
        onExited: {
            if (root._destroying) return;
            monitorReconnectTimer.interval = root.monitorRetryDelay;
            monitorReconnectTimer.restart();
            root.monitorRetryDelay = Math.min(root.monitorRetryMaxDelay, root.monitorRetryDelay * 2);
        }
    }

    Timer {
        id: monitorReconnectTimer
        repeat: false
        onTriggered: root.startMonitor()
    }

    Timer {
        id: monitorStableTimer
        interval: 5000
        repeat: false
        onTriggered: root.monitorRetryDelay = 1000
    }
}
