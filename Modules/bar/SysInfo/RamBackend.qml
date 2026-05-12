import QtQuick
import Quickshell.Io

Item {
    id: backend

    property string ramUsageVal: "..."
    property string ramUsagePct: "0"
    property string ramTotal: "..."
    property string swapUsed: "..."
    property string swapTotal: "..."
    property var ramHistory: []
    property int ramHistMax: 40

    Process {
        id: memProc
        command: ["sh", "-c", "free -m | awk '/Mem/ {printf(\"%.0f|%.1f|%.1f\", $3/$2*100, $3/1024, $2/1024)} /Swap/ {printf(\"|%.1f|%.1f\", $3/1024, $2/1024)}'"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { memProc.buf = data.trim(); } }
        onExited: {
            if (memProc.buf === "") return;
            var parts = memProc.buf.split("|");
            if (parts.length >= 5) {
                backend.ramUsagePct = parts[0];
                backend.ramUsageVal = parts[1] + " GB";
                backend.ramTotal = parts[2] + " GB";
                backend.swapUsed = parts[3] + " GB";
                backend.swapTotal = parts[4] + " GB";
                backend.ramHistory.push(parseInt(backend.ramUsagePct));
                if (backend.ramHistory.length > backend.ramHistMax) backend.ramHistory.shift();
            }
            memProc.buf = "";
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }
}
