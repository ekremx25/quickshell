import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
    id: root

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17

    property bool hasBattery: false
    property int batteryLevel: 100
    property string batteryStatus: "Unknown" // Charging, Discharging, Full, Not charging
    property bool onAC: true

    color: {
        if (!hasBattery) return Theme.batteryColor
        if (batteryStatus === "Charging") return Theme.batteryColor
        if (batteryLevel <= 15) return Theme.red
        if (batteryLevel <= 35) return Theme.tempColor
        return Theme.batteryColor
    }

    Behavior on color { ColorAnimation { duration: 200 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: {
                if (!root.hasBattery) return "󰚥" // Plug icon for desktop/AC
                if (root.batteryStatus === "Charging") return "󰂄"
                if (root.batteryLevel >= 90) return "󰁹"
                if (root.batteryLevel >= 70) return "󰂁"
                if (root.batteryLevel >= 50) return "󰁾"
                if (root.batteryLevel >= 30) return "󰁼"
                if (root.batteryLevel >= 15) return "󰁺"
                return "󰂎" // Critical
            }
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: "#1e1e2e"
        }

        Text {
            text: root.hasBattery ? root.batteryLevel + "%" : "AC"
            font.bold: true
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: "#1e1e2e"
        }
    }

    // --- DETECT BATTERY ---
    Process {
        id: detectProc
        command: ["bash", "-c", "ls /sys/class/power_supply/ 2>/dev/null"]
        property string output: ""
        stdout: SplitParser { onRead: data => detectProc.output += data + " " }
        onExited: {
            var supplies = detectProc.output.trim().split(/\s+/)
            var foundBat = false
            for (var i = 0; i < supplies.length; i++) {
                if (supplies[i].indexOf("BAT") !== -1) {
                    foundBat = true
                    break
                }
            }
            root.hasBattery = foundBat
            if (foundBat) {
                readBattery.running = true
            }
            detectProc.output = ""
        }
    }

    // --- READ BATTERY ---
    Process {
        id: readBattery
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null; echo '---'; cat /sys/class/power_supply/BAT*/status 2>/dev/null"]
        property string output: ""
        stdout: SplitParser { onRead: data => readBattery.output += data + "\n" }
        onExited: {
            var parts = readBattery.output.split("---")
            if (parts.length >= 2) {
                var cap = parseInt(parts[0].trim())
                if (!isNaN(cap)) root.batteryLevel = cap
                var status = parts[1].trim().split("\n")[0].trim()
                if (status.length > 0) root.batteryStatus = status
            }
            readBattery.output = ""
        }
    }

    // --- AC STATUS ---
    Process {
        id: acProc
        command: ["bash", "-c", "cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null || echo 1"]
        property string output: ""
        stdout: SplitParser { onRead: data => acProc.output += data }
        onExited: {
            root.onAC = acProc.output.trim() === "1"
            acProc.output = ""
        }
    }

    // --- POLLING ---
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (root.hasBattery) {
                readBattery.output = ""
                readBattery.running = true
            }
            acProc.output = ""
            acProc.running = true
        }
    }

    Component.onCompleted: {
        detectProc.running = true
        acProc.running = true
    }

    // Tooltip on hover
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    // Custom tooltip
    Rectangle {
        visible: hoverArea.containsMouse
        x: (root.width - width) / 2
        y: root.height + 6
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8
        radius: 6
        color: Theme.background
        border.color: Theme.surface
        border.width: 1
        z: 100

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: {
                if (!root.hasBattery) return "Masaüstü — AC Güç"
                return root.batteryLevel + "% — " + root.batteryStatus
            }
            color: Theme.text
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }
    }
}
