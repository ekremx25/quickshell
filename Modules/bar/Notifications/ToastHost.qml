import QtQuick
import Quickshell
import "../../../Services"

Item {
    id: root

    visible: false
    width: 0
    height: 0

    Loader {
        id: toastLoader
        source: "Toast.qml"
        active: true
    }

    Connections {
        target: Notifications

        function onPopupPositionChanged() {
            toastLoader.active = false;
            Qt.callLater(function() { toastLoader.active = true; });
        }
    }
}
