import QtQuick
import Quickshell.Io
import "../../../Services/core/Log.js" as Log

Item {
    id: service

    visible: false
    width: 0
    height: 0

    property string diskUsed: "0G"
    property string diskTotal: "0G"
    property string diskPercent: "0%"

    function refresh() {
        if (diskProc.running) return;
        diskProc.output = "";
        diskProc.running = true;
    }

    function parseDiskStats(text) {
        var parts = String(text || "").trim().split("|");
        if (parts.length < 3) return;
        service.diskUsed = parts[0];
        service.diskTotal = parts[1];
        service.diskPercent = parts[2];
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $3 \"|\" $2 \"|\" $5}'"]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => { diskProc.output += data; } }
        onExited: {
            try {
                service.parseDiskStats(diskProc.output);
            } catch (e) {
                Log.warn("DiskService", "Disk stats parse error: " + e);
            }
            diskProc.output = "";
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
