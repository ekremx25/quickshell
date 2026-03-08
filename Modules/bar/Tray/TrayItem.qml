import QtQuick
import Quickshell

MouseArea {
    id: root

    // Sistemden gelen veri
    required property var modelData

    implicitWidth: 30
    implicitHeight: 30

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    property bool menuOpening: false

    // Sol ve Sağ Tıkı Kabul Et
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

    // --- MENÜ ÇAPASI ---
    QsMenuAnchor {
        id: menuAnchor
        menu: modelData.menu
        anchor.item: root
    }

    // --- ARKA PLAN ---
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: (root.containsMouse || root.menuOpening) ? Qt.rgba(205/255, 214/255, 244/255, root.menuOpening ? 0.20 : 0.12) : "transparent"
        border.color: (root.containsMouse || root.menuOpening) ? Qt.rgba(137/255, 180/255, 250/255, root.menuOpening ? 0.38 : 0.2) : "transparent"
        border.width: 1
        scale: root.menuOpening ? 1.08 : (root.containsMouse ? 1.03 : 1.0)

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    // --- İKON ---
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
            const raw = root.modelData.icon;

            // Spotify düzeltmesi
            if (raw && raw.indexOf("spotify") !== -1) {
                return "image://icon/spotify";
            }
            
            // Fix for missing nm-connection-editor icon
            if (raw === "nm-connection-editor") {
                return "image://icon/preferences-system-network";
            }

            return raw;
        }

        // Hover'da hafif büyüme efekti
        scale: root.menuOpening ? 1.16 : (root.containsMouse ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Hover'da opaklık artışı
        opacity: root.containsMouse ? 1.0 : 0.75
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
