import QtQuick
import Quickshell.Io

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property bool hasBattery: false
    property int batteryLevel: 100
    property string batteryStatus: "Unknown"
    property bool onAC: true

    function refresh() {
        if (hasBattery) {
            readBattery.output = "";
            readBattery.running = true;
        }
        acProc.output = "";
        acProc.running = true;
    }

    Process {
        id: detectProc
        command: ["bash", "-c", "ls /sys/class/power_supply/ 2>/dev/null"]
        property string output: ""
        stdout: SplitParser { onRead: data => detectProc.output += data + " " }
        onExited: {
            var supplies = detectProc.output.trim().split(/\s+/);
            var foundBat = false;
            for (var i = 0; i < supplies.length; i++) {
                if (supplies[i].indexOf("BAT") !== -1) {
                    foundBat = true;
                    break;
                }
            }
            service.hasBattery = foundBat;
            if (foundBat) readBattery.running = true;
            detectProc.output = "";
        }
    }

    Process {
        id: readBattery
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null; echo '---'; cat /sys/class/power_supply/BAT*/status 2>/dev/null"]
        property string output: ""
        stdout: SplitParser { onRead: data => readBattery.output += data + "\n" }
        onExited: {
            var parts = readBattery.output.split("---");
            if (parts.length >= 2) {
                var cap = parseInt(parts[0].trim());
                if (!isNaN(cap)) service.batteryLevel = cap;
                var status = parts[1].trim().split("\n")[0].trim();
                if (status.length > 0) service.batteryStatus = status;
            }
            readBattery.output = "";
        }
    }

    Process {
        id: acProc
        command: ["bash", "-c", "cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null || echo 1"]
        property string output: ""
        stdout: SplitParser { onRead: data => acProc.output += data }
        onExited: {
            service.onAC = acProc.output.trim() === "1";
            acProc.output = "";
        }
    }

    Component.onCompleted: {
        detectProc.running = true;
        acProc.running = true;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: service.refresh()
    }
}
