import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"

Rectangle {
    id: root
    height: 30
    width: layout.implicitWidth + 16
    radius: 15
    color: Theme.ramColor
    Behavior on color { ColorAnimation { duration: Theme.animMedium } }
    property bool isHovered: ma.containsMouse || tipWindow.visible
    RamBackend { id: backend }
    border.width: 1
    border.color: isHovered ? Theme.withAlpha(Theme.text, 0.1) : "transparent"

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: backend.ramUsageVal
            font.bold: true
            font.family: Theme.fontFamily
            color: Theme.foregroundFor(root.color)
        }
        Text {
            font.family: Theme.iconFontFamily
            text: "" // RAM Icon
            font.pixelSize: 14
            color: Theme.foregroundFor(root.color)
        }
    }

    // --- TOOLTIP ---
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tipWindow.visible = true
        onExited: tipWindow.visible = false
    }

    HistoryTooltip {
        id: tipWindow
        ownerItem: root
        accentColor: Theme.ramColor
        primaryLineLeft: "Usage: " + backend.ramUsagePct + "%"
        primaryLineRight: "RAM: " + backend.ramUsageVal + " / " + backend.ramTotal
        historyValues: backend.ramHistory
        historyMax: backend.ramHistMax
        detailLines: [
            { text: "Swap Used: " + backend.swapUsed },
            { text: "Swap Total: " + backend.swapTotal }
        ]
    }
}
