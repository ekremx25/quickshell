import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services"

Rectangle {
    id: root

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17
    color: Theme.surface

    opacity: mouseArea.pressed ? 0.8 : 1.0
    Behavior on opacity { NumberAnimation { duration: 100 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰣐" // Configuration/Settings icon
            color: Theme.text
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ControlCenterState.toggleRequested()
        }
    }
}
