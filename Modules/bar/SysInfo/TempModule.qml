import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 32
    color: "#f5c2e7" // Pink
    radius: 15

    // Patch that flattens the left side
    Rectangle {
        width: 15
        height: parent.height
        color: root.color
        anchors.left: parent.left
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: tempText
            text: "--°C"
            font.bold: true
            font.family: Theme.fontFamily
            color: "#1e1e2e"
            font.pixelSize: 14
        }

        Text {
            font.family: Theme.iconFontFamily
            text: "" // If your font has it you can use "󰏈"
            font.pixelSize: 16
            color: "#1e1e2e"
        }
    }

    // --- MOST ROBUST METHOD: Find and Read the Hardware File ---
    Process {
        id: tempProc
        // This command does the following:
        // 1. Walks through the hwmon folders.
        // 2. Searches for the "k10temp" name (your CPU).
        // 3. Reads the temperature file (temp1_input) from the folder it finds.
        // 4. Much lighter than running the "sensors" command.
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do grep -q k10temp $h/name && cat $h/temp1_input && exit; done"]
    }

    // --- DATA READING ---
    Connections {
        // Only connect while the process is running (Critical to avoid errors!)
        target: tempProc.running ? tempProc.stdout : null

        function onRead(data) {
            var rawVal = data.toString().trim()

            // Check if the incoming data is a number (e.g. 46125 arrives)
            if (rawVal !== "" && !isNaN(rawVal)) {
                // Divide by 1000 and convert to degrees: 46125 -> 46.1
                var temp = (parseInt(rawVal) / 1000).toFixed(1)
                tempText.text = "+" + temp + "°C"
            }
        }
    }

    // --- TIMER (2 Seconds) ---
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tempProc.running = true
    }
}
