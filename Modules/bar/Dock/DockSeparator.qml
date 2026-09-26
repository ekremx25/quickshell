import QtQuick

// Separator follows the dock axis.
Rectangle {
    required property real dockScale
    required property real iconSize

    property bool horizontal: true

    width: (horizontal ? 1 : iconSize * 0.6) * dockScale
    height: (horizontal ? iconSize * 0.6 : 1) * dockScale
    color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
}
