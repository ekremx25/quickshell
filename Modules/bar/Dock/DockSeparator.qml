import QtQuick

// Thin vertical separator, used between left modules / apps / right modules.
Rectangle {
    required property real dockScale
    required property real iconSize

    width: 1 * dockScale
    height: iconSize * 0.6 * dockScale
    color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
    anchors.verticalCenter: parent.verticalCenter
}
