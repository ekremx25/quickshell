import QtQuick
import "../../../Widgets"

// Small tooltip shown above a dock item on hover.
Rectangle {
    id: tooltip

    required property string label
    required property real dockScale
    required property bool shown

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: 10 * dockScale

    width: tooltipText.implicitWidth + (18 * dockScale)
    height: tooltipText.implicitHeight + (10 * dockScale)
    radius: 9 * dockScale
    color: Qt.rgba(30/255, 30/255, 46/255, 0.96)
    border.color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
    border.width: 1

    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Text {
        id: tooltipText
        anchors.centerIn: parent
        text: tooltip.label
        color: Theme.text
        font.pixelSize: 11 * tooltip.dockScale
        font.bold: true
    }
}
