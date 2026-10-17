import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services" as S

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 32
    color: Theme.tempColor
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
            // Shares the CPU temperature sampled by CpuStats instead of polling hwmon separately.
            text: S.CpuStats.cpuTempC === "-" ? "--°C" : "+" + S.CpuStats.cpuTempC + "°C"
            font.bold: true
            font.family: Theme.fontFamily
            color: Theme.foregroundFor(root.color)
            font.pixelSize: 14
        }

        Text {
            font.family: Theme.iconFontFamily
            text: "" // If your font has it you can use "󰏈"
            font.pixelSize: 16
            color: Theme.foregroundFor(root.color)
        }
    }
}
