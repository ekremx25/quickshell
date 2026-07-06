import QtQuick
import Quickshell.Io
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property bool active: true

    property string ifaceName: ""
    property string ipAddr: ""
    property string gateway: ""
    property string connName: ""
    property string connStatus: "Checking..."
    property string macAddr: ""
    property string dns: ""
    property string connType: ""

    property string ipv4Method: "auto"
    property string ipv6Method: "auto"
    property string dnsMethod: "auto"
    property string proxyMethod: "none"
    property string mtuValue: "1500"
    property string macMode: "default"

    property var wifiList: []
    property string connectingSsid: ""

    property string applyStatus: ""
    property bool applyError: false

    function clearTransientState() {
        applyStatus = ""
        applyError = false
    }

    function restartProcess(proc, clearBuffer) {
        if (clearBuffer && proc.buf !== undefined) proc.buf = "";
        proc.running = false;
        proc.running = true;
    }

    function runProcess(proc, nextCommand) {
        proc.running = false;
        proc.command = nextCommand;
        proc.running = true;
    }

    function runManagedProcess(proc, nextCommand, statusText) {
        if (statusText !== undefined) applyStatus = statusText;
        runProcess(proc, nextCommand);
    }

    function refreshCoreNetworkState() {
        restartProcess(nmcliProc, true);
        restartProcess(ipProc, true);
        restartProcess(gwProc, true);
    }

    function refreshConnectionState() {
        refreshCoreNetworkState();
        restartProcess(dnsProc, true);
    }

    function refreshWifiScan() {
        restartProcess(wifiScanProc, true);
    }

    function refresh() {
        refreshConnectionState();
        refreshDelayTimer.restart();
    }

    function refreshAll() {
        refreshConnectionState();
        refreshWifiScan();
    }

    function queueApplyCommand(commandArgs) {
        applyStatus = "Applying...";
        applyError = false;
        applyProc.errBuf = "";
        runProcess(applyProc, commandArgs);
    }

    function activateConnection() {
        applyStatus = "⏳ Restarting connection...";
        applyError = false;
        connUpProc.errBuf = "";
        runProcess(connUpProc, ["nmcli", "connection", "up", connName]);
    }

    function disconnectCurrentDevice() {
        if (ifaceName) {
            runProcess(disconnectProc, ["nmcli", "device", "disconnect", ifaceName]);
        }
    }

    function connectToWifi(ssid) {
        if (!ssid || connectingSsid !== "") return;
        connectingSsid = ssid;
        runProcess(connectProc, ["nmcli", "device", "wifi", "connect", ssid]);
    }

    function applyMtu() {
        if (!connName) return;
        queueApplyCommand(["nmcli", "connection", "modify", connName, "802-3-ethernet.mtu", mtuValue]);
    }

    function applyMacMode() {
        if (!connName) return;
        var macVal = macMode === "default" ? "" : macAddr;
        queueApplyCommand(["nmcli", "connection", "modify", connName, "802-3-ethernet.cloned-mac-address", macVal || "permanent"]);
    }

    function applyConnectionSettings(commandArgs) {
        queueApplyCommand(commandArgs);
    }

    function parseDeviceStatus(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(":");
            if (parts.length >= 4 && parts[2] === "connected") {
                ifaceName = parts[0];
                connName = parts[3];
                connType = parts[1];
                connStatus = "Connected";
                macProc.iface = parts[0];
                restartProcess(macProc, true);
                connDetailProc.conn = parts[3];
                restartProcess(connDetailProc, true);
                return;
            }
        }

        ifaceName = "";
        connName = "";
        connType = "";
        connStatus = "Disconnected";
    }

    function parseConnectionDetails(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(":");
            if (parts[0] === "ipv4.method") ipv4Method = parts[1] || "auto";
            if (parts[0] === "ipv6.method") ipv6Method = parts[1] || "auto";
            if (parts[0] === "802-3-ethernet.mtu") mtuValue = (parts[1] && parts[1] !== "" && parts[1] !== "0") ? parts[1] : "1500";
        }
    }

    function parseWifiList(text) {
        var lines = text.split("\n");
        var list = [];
        var seen = {};

        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(/^(.*):(\\d+):(.*):(.*):(yes|no)$/);
            if (!match) continue;
            var ssid = match[1].replace(/\\:/g, ":");
            var signal = parseInt(match[2]);
            var security = match[3];
            var bars = match[4];
            var activeNetwork = match[5] === "yes";

            if (!ssid || seen[ssid]) continue;
            seen[ssid] = true;
            list.push({ ssid: ssid, signal: signal, security: security, bars: bars, active: activeNetwork });
        }

        list.sort(function(a, b) {
            return a.active ? -1 : b.active ? 1 : b.signal - a.signal;
        });

        wifiList = list;
    }

    onActiveChanged: {
        if (active) refreshAll();
    }

    Component.onCompleted: {
        if (active) refreshAll();
    }

    Process {
        id: nmcliProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        property string buf: ""
        stdout: SplitParser { onRead: data => nmcliProc.buf += data + "\n" }
        onExited: {
            parseDeviceStatus(nmcliProc.buf);
            nmcliProc.buf = "";
        }
    }

    Process {
        id: ipProc
        command: ["ip", "-4", "-o", "addr", "show"]
        property string buf: ""
        stdout: SplitParser { onRead: data => ipProc.buf += data + "\n" }
        onExited: {
            var lines = ipProc.buf.split("\n");
            var addr = "";
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].trim().split(/\s+/);
                var inetIdx = parts.indexOf("inet");
                if (inetIdx >= 0 && inetIdx + 1 < parts.length) {
                    var cidr = parts[inetIdx + 1];
                    if (cidr.indexOf("127.") !== 0) { addr = cidr; break; }
                }
            }
            ipAddr = addr;
            ipProc.buf = "";
        }
    }

    Process {
        id: gwProc
        command: ["ip", "-4", "route", "list", "default"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { if (!gwProc.buf) gwProc.buf = data.trim(); } }
        onExited: {
            var parts = gwProc.buf.split(/\s+/);
            var viaIdx = parts.indexOf("via");
            gateway = (viaIdx >= 0 && viaIdx + 1 < parts.length) ? parts[viaIdx + 1] : "";
            gwProc.buf = "";
        }
    }

    Process {
        id: macProc
        property string iface: ""
        command: iface.length > 0 ? ["cat", "/sys/class/net/" + iface + "/address"] : []
        property string buf: ""
        stdout: SplitParser { onRead: data => macProc.buf = data.trim() }
        onExited: {
            macAddr = macProc.buf || "--";
            macProc.buf = "";
        }
    }

    Process {
        id: dnsProc
        command: ["nmcli", "-t", "-f", "IP4.DNS", "connection", "show", "--active"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { if (!dnsProc.buf) dnsProc.buf = data.trim(); } }
        onExited: {
            var line = dnsProc.buf;
            var idx = line.indexOf(":");
            dns = (idx >= 0 ? line.substring(idx + 1) : line) || "Automatic";
            dnsProc.buf = "";
        }
    }

    Process {
        id: connDetailProc
        property string conn: ""
        command: conn.length > 0
            ? ["nmcli", "-t", "-f", "ipv4.method,ipv6.method,802-3-ethernet.mtu", "connection", "show", conn]
            : []
        property string buf: ""
        stdout: SplitParser { onRead: data => connDetailProc.buf += data + "\n" }
        onExited: {
            parseConnectionDetails(connDetailProc.buf);
            connDetailProc.buf = "";
        }
    }

    Process {
        id: wifiScanProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BARS,ACTIVE", "device", "wifi", "list", "--rescan", "no"]
        property string buf: ""
        stdout: SplitParser { onRead: data => wifiScanProc.buf += data + "\n" }
        onExited: {
            parseWifiList(wifiScanProc.buf);
            wifiScanProc.buf = "";
        }
    }

    Process {
        id: connectProc
        command: []
        onExited: {
            connectingSsid = "";
            refreshAll();
        }
    }

    Process {
        id: disconnectProc
        command: []
        onExited: refreshConnectionState()
    }

    Process {
        id: applyProc
        command: []
        property string errBuf: ""
        stdout: SplitParser { onRead: data => Log.debug("NetworkService", "[net-apply] " + data) }
        stderr: SplitParser { onRead: data => { applyProc.errBuf += data + " "; Log.warn("NetworkService", "[net-apply err] " + data); } }
        onExited: code => {
            if (code !== 0) {
                applyStatus = "❌ Modify error: " + applyProc.errBuf;
                applyError = true;
            } else {
                activateConnection();
            }
            applyProc.errBuf = "";
        }
    }

    Process {
        id: connUpProc
        command: []
        property string errBuf: ""
        stdout: SplitParser { onRead: data => Log.debug("NetworkService", "[conn-up] " + data) }
        stderr: SplitParser { onRead: data => { connUpProc.errBuf += data + " "; Log.warn("NetworkService", "[conn-up err] " + data); } }
        onExited: code => {
            if (code !== 0) {
                applyStatus = "❌ Connection error: " + connUpProc.errBuf;
                applyError = true;
            } else {
                applyStatus = "✅ IP changed successfully!";
                applyError = false;
                refreshDelayTimer.restart();
            }
            connUpProc.errBuf = "";
        }
    }

    Process {
        id: nmMonitorProc
        command: ["nmcli", "monitor"]
        running: active
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "") monitorDebounceTimer.restart();
            }
        }
    }

    Timer {
        id: refreshDelayTimer
        interval: 2000
        repeat: false
        onTriggered: refreshAll()
    }

    Timer {
        id: monitorDebounceTimer
        interval: 800
        repeat: false
        onTriggered: refreshAll()
    }
}
