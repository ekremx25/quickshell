import QtQuick

// Free-floating icon shown at the cursor position while an item is being dragged.
Rectangle {
    id: ghost

    required property bool isDragging
    required property string dragIcon
    required property real dragGlobalX
    required property real dragGlobalY
    required property real dockScale
    required property var backend

    visible: isDragging
    width: 36 * dockScale
    height: 36 * dockScale
    radius: 14 * dockScale
    color: "transparent"
    z: 9999

    x: dragGlobalX - (width / 2)
    y: dragGlobalY - (height / 2)

    Image {
        anchors.fill: parent
        source: {
            if (!ghost.dragIcon) return "";
            if (ghost.dragIcon.startsWith("/")) return "file://" + ghost.dragIcon;
            return "image://icon/" + ghost.backend.resolveThemedIconName(ghost.dragIcon);
        }
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
