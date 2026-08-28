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
        active: true

        sourceComponent: Component {
            Variants {
                model: ScreenManager.getFilteredScreens("toast")

                delegate: Toast {}
            }
        }
    }

    Connections {
        target: Notifications

        function onPopupPositionChanged() {
            toastLoader.active = false;
            Qt.callLater(function() { toastLoader.active = true; });
        }
    }
}
