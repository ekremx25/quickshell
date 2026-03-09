import QtQuick
import Quickshell
import "../../../Widgets"

MouseArea {
    id: root

    required property var modelData
    property string rawIconName: modelData && modelData.icon ? String(modelData.icon) : ""

    implicitWidth: 30
    implicitHeight: 30

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    property bool menuOpening: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (event) => {
        if (event.button === Qt.LeftButton) {
            modelData.activate();
        } else if (event.button === Qt.RightButton) {
            if (menuAnchor.menu) {
                root.menuOpening = true
                openMenuTimer.restart()
            }
        }
    }

    Timer {
        id: openMenuTimer
        interval: 90
        repeat: false
        onTriggered: {
            menuAnchor.open()
            root.menuOpening = false
        }
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: modelData.menu
        anchor.item: root
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 24
        height: 24
        radius: 8
        color: root.menuOpening ? Qt.rgba(1, 1, 1, 0.62) : (root.containsMouse ? Qt.rgba(1, 1, 1, 0.52) : Qt.rgba(1, 1, 1, 0.42))
        border.color: root.menuOpening ? Qt.rgba(1, 1, 1, 0.80) : (root.containsMouse ? Qt.rgba(1, 1, 1, 0.66) : Qt.rgba(1, 1, 1, 0.34))
        border.width: 1
        scale: root.menuOpening ? 1.08 : (root.containsMouse ? 1.04 : 1.0)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Image {
        id: content
        anchors.centerIn: parent
        width: 18
        height: 18

        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        source: {
            const raw = root.rawIconName;

            if (!raw) {
                return "image://icon/application-x-executable";
            }

            if (raw.startsWith("image://") || raw.startsWith("/") || raw.startsWith("file:")) {
                return raw;
            }

            if (raw.indexOf("spotify") !== -1) {
                return "image://icon/spotify";
            }

            if (raw === "nm-connection-editor") {
                return "image://icon/preferences-system-network";
            }

            return "image://icon/" + raw.replace(/-symbolic$/, "");
        }

        scale: root.menuOpening ? 1.12 : (root.containsMouse ? 1.06 : 1.0)
        opacity: 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
