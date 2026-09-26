import QtQuick
import "../../../Widgets"

// Small tooltip shown above a dock item on hover.
DockPopup {
    id: tooltip

    required property string label
    required property real dockScale

    implicitWidth: Math.min(tooltipText.implicitWidth + 18 * dockScale, 360 * dockScale)
    implicitHeight: tooltipText.implicitHeight + 10 * dockScale

    Rectangle {
        anchors.fill: parent
        radius: 9 * tooltip.dockScale
        color: Theme.withAlpha(Theme.background, 0.96)
        border.color: Theme.withAlpha(Theme.surface, 0.8)
        border.width: 1
    }

    Text {
        font.family: Theme.fontFamily
        id: tooltipText
        anchors.centerIn: parent
        width: tooltip.width - 18 * tooltip.dockScale
        elide: Text.ElideRight
        text: tooltip.label
        color: Theme.text
        font.pixelSize: 11 * tooltip.dockScale
        font.bold: true
    }
}
