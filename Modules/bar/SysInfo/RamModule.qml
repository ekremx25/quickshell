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
    property bool isHovered: ma.containsMouse || tipWindow.visible
    RamBackend { id: backend }

    border.width: 1
    border.color: isHovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: backend.ramUsageVal
            font.bold: true
            color: "#1e1e2e"
        }
        Text {
            text: "" // RAM Icon
            font.pixelSize: 14
            color: "#1e1e2e"
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
        accentColor: "#cba6f7"
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
