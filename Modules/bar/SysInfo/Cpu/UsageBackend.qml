import QtQuick
import Quickshell.Io

Item {
    id: backend

    property string totalUsage: "0%"
    property var previousStats: ({})
    property alias coreModel: coreModel

    ListModel { id: coreModel }

    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("cpu")) return;
                var parts = line.split(/\s+/);
                var name = parts[0];
                var idle = parseFloat(parts[4]) + parseFloat(parts[5]);
                var total = 0;
                for (var i = 1; i < parts.length; i++) {
                    var val = parseFloat(parts[i]);
                    if (!isNaN(val)) total += val;
                }
                var prev = backend.previousStats[name] || { total: 0, idle: 0 };
                var diffTotal = total - prev.total;
                var diffIdle = idle - prev.idle;
                var usagePerc = 0;
                if (diffTotal > 0) usagePerc = (diffTotal - diffIdle) / diffTotal * 100;

                backend.previousStats[name] = { total: total, idle: idle };
                var finalStr = Math.round(usagePerc) + "%";

                if (name === "cpu") {
                    backend.totalUsage = finalStr;
                    return;
                }

                var coreName = name.replace("cpu", "Core ");
                for (var k = 0; k < coreModel.count; k++) {
                    if (coreModel.get(k).name === coreName) {
                        coreModel.setProperty(k, "usage", finalStr);
                        return;
                    }
                }
                coreModel.append({ name: coreName, usage: finalStr });
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
}
