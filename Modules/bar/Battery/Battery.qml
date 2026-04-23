import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

Rectangle {
    id: root

    BatteryService { id: batteryService }

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17

    property alias hasBattery: batteryService.hasBattery
    property alias batteryLevel: batteryService.batteryLevel
    property alias batteryStatus: batteryService.batteryStatus
    property alias onAC: batteryService.onAC

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
            font.family: Theme.fontFamily
            color: "#1e1e2e"
        }
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
                if (!root.hasBattery) return "Desktop — AC Power"
                return root.batteryLevel + "% — " + root.batteryStatus
            }
            color: Theme.text
            font.pixelSize: 11
            font.family: Theme.fontFamily
        }
    }
}
